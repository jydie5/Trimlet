using System.Text;
using System.Text.Json;
using Trimlet.Media;

namespace Trimlet.Contracts.Tests;

[TestClass]
public sealed class ProjectContractTests
{
    [TestMethod]
    public void EverySharedProjectFixtureIsEnforcedAndRoundTrips()
    {
        using var fixtures = JsonDocument.Parse(File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "contracts", "fixtures", "project-cases.json")));
        foreach (var test in fixtures.RootElement.GetProperty("cases").EnumerateArray())
        {
            var bytes = Encoding.UTF8.GetBytes(test.GetProperty("input").GetRawText());
            Exception? error = null;
            TrimletProject? project = null;
            try { project = TrimletProject.Decode(bytes); } catch (Exception exception) { error = exception; }
            Assert.AreEqual(test.GetProperty("valid").GetBoolean(), error is null, test.GetProperty("id").GetString());
            if (project is not null)
            {
                var copy = TrimletProject.Decode(project.Encode());
                Assert.IsTrue(project.ToEditList().Equals(copy.ToEditList()));
                Assert.AreEqual(project.Settings, copy.Settings);
                Assert.AreEqual(project.Source, copy.Source);
                CollectionAssert.AreEqual(project.EditList.Segments, copy.EditList.Segments);
            }
        }
    }

    [TestMethod]
    public void NestedUnknownsMissingFieldsNullsAndOversizeAreRejected()
    {
        var template = """{"schemaVersion":1,"source":{"fileName":"a.mp4","pathHint":"a.mp4"},"editList":{"segments":[]},"settings":{"exportMode":"fast"}}""";
        foreach (var json in new[]
        {
            template.Replace("\"exportMode\":\"fast\"", "\"exportMode\":\"fast\",\"extra\":1"),
            template.Replace("\"segments\":[]", "\"segments\":[],\"extra\":1"),
            template.Replace("\"pathHint\":\"a.mp4\"", "\"pathHint\":null"),
            template.Replace("\"schemaVersion\":1,", ""),
        })
        {
            var rejected = false;
            try { TrimletProject.Decode(Encoding.UTF8.GetBytes(json)); } catch { rejected = true; }
            Assert.IsTrue(rejected, json);
        }
        Assert.ThrowsExactly<InvalidDataException>(() => TrimletProject.Decode(new byte[TrimletProject.MaximumBytes + 1]));
    }
}
