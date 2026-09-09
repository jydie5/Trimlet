using Trimlet.Media;
using Trimlet.Platform.Windows;

namespace Trimlet.Media.Tests;

[TestClass]
public sealed class ProjectStoreTests
{
    [TestMethod]
    public async Task PortableSourceAndAtomicSavePreserveTimestampsAndExistingFileOnFailure()
    {
        var directory = Path.Combine(Path.GetTempPath(), "trimlet-project-test-" + Guid.NewGuid());
        Directory.CreateDirectory(Path.Combine(directory, "編集"));
        try
        {
            var source = Path.Combine(directory, "動画 sample.mp4");
            await File.WriteAllBytesAsync(source, [1, 2, 3]);
            var path = Path.Combine(directory, "編集", "sample.trimlet");
            var reference = ProjectStore.Capture(source, path);
            Assert.AreEqual("../動画 sample.mp4", reference.PathHint);
            Assert.AreEqual(source, ProjectStore.Resolve(reference, path));
            Assert.IsTrue(ProjectStore.Matches(reference, source));
            var project = new TrimletProject(1, reference,
                new([new(Guid.NewGuid(), new(600000, 60000), new(1200000, 60000), "Opening")]), new("accurate", new(2)));
            await ProjectStore.SaveAsync(path, project);
            var copy = await ProjectStore.ReadAsync(path);
            Assert.AreEqual(60000, copy.EditList.Segments[0].In.Timescale);
            Assert.AreEqual(600000L, copy.EditList.Segments[0].In.Value);
            Assert.ThrowsExactly<ArgumentOutOfRangeException>(() => copy.Validate(new MediaTimestamp(19, 1)));
            var original = await File.ReadAllBytesAsync(path);
            var oversized = project with { Source = reference with { FileName = new string('a', TrimletProject.MaximumBytes) } };
            await Assert.ThrowsExactlyAsync<InvalidDataException>(() => ProjectStore.SaveAsync(path, oversized));
            CollectionAssert.AreEqual(original, await File.ReadAllBytesAsync(path));
            await ProjectStore.SaveAsync(path, project with { Settings = new("fast") });
            Assert.AreEqual("fast", (await ProjectStore.ReadAsync(path)).Settings.ExportMode);
            await File.AppendAllTextAsync(source, "changed");
            Assert.IsFalse(ProjectStore.Matches(reference, source));
            Assert.IsEmpty(Directory.GetFiles(Path.GetDirectoryName(path)!, "*.tmp"));
        }
        finally { Directory.Delete(directory, true); }
    }
}
