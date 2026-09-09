using System.IO.Compression;
using Trimlet.Platform.Windows;

namespace Trimlet.Media.Tests;

[TestClass]
public sealed class VideoToolSetupTests
{
    private string _root = null!;
    [TestInitialize] public void Setup() => _root = Directory.CreateTempSubdirectory("trimlet-tools-test-").FullName;
    [TestCleanup] public void Cleanup() => Directory.Delete(_root, true);

    private string Archive(params string[] paths)
    {
        var file = Path.Combine(_root, "test.zip");
        using var zip = ZipFile.Open(file, ZipArchiveMode.Create);
        foreach (var path in paths)
        {
            using var writer = new StreamWriter(zip.CreateEntry(path).Open());
            writer.Write("synthetic fixture");
        }
        return file;
    }

    [TestMethod]
    public void ExtractsPackageAndPreservesLicense()
    {
        var zip = Archive("package/bin/ffmpeg.exe", "package/LICENSE.txt");
        VideoToolSetup.ExtractChecked(zip, Path.Combine(_root, "out"), "package", default);
        Assert.IsTrue(File.Exists(Path.Combine(_root, "out/package/LICENSE.txt")));
    }

    [TestMethod]
    [DataRow("package/../escape.txt")]
    [DataRow("package/bin/tool.exe:stream")]
    [DataRow("/package/bin/tool.exe")]
    [DataRow("different/bin/tool.exe")]
    [DataRow("package/./tool.exe")]
    [DataRow("package/..\\escape.txt")]
    public void RejectsUnsafePaths(string path)
    {
        var zip = Archive(path);
        Assert.ThrowsExactly<InvalidDataException>(() => VideoToolSetup.ExtractChecked(zip, Path.Combine(_root, "out"), "package", default));
    }

    [TestMethod]
    public void RejectsCaseInsensitiveDuplicates()
    {
        var zip = Archive("package/bin/a.exe", "package/bin/A.exe");
        Assert.ThrowsExactly<InvalidDataException>(() => VideoToolSetup.ExtractChecked(zip, Path.Combine(_root, "out"), "package", default));
    }

    [TestMethod]
    public void CancellationDoesNotExtractFiles()
    {
        var zip = Archive("package/bin/a.exe");
        Assert.ThrowsExactly<OperationCanceledException>(() => VideoToolSetup.ExtractChecked(zip, Path.Combine(_root, "out"), "package", new CancellationToken(true)));
        Assert.IsFalse(Directory.Exists(Path.Combine(_root, "out")));
    }

    [TestMethod]
    public async Task RejectsTruncatedDownload()
    {
        var zip = Archive("package/bin/a.exe");
        await Assert.ThrowsExactlyAsync<InvalidDataException>(() => VideoToolSetup.VerifyArchiveAsync(zip, default));
    }

    [TestMethod]
    public async Task RejectsWrongHashEvenWhenSizeMatches()
    {
        var file = Path.Combine(_root, "wrong.zip");
        using (var stream = File.Create(file)) stream.SetLength(VideoToolSetup.ArchiveSize);
        await Assert.ThrowsExactlyAsync<InvalidDataException>(() => VideoToolSetup.VerifyArchiveAsync(file, default));
    }
}
