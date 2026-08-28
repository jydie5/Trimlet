using System.Text.Json;
using Trimlet.Media;

namespace Trimlet.Contracts.Tests;

[TestClass]
public sealed class SharedContractTests
{
    [TestMethod]
    public void ErrorCodeCatalogLoadsEveryCanonicalIdentifier()
    {
        using var stream = File.OpenRead(ContractPath("error-codes.json"));
        var contract = ContractCatalog.ReadErrorCodes(stream);

        string[] expected =
        [
            "source_unreadable",
            "unsupported_streams",
            "proxy_failed",
            "invalid_range",
            "output_conflict",
            "insufficient_space",
            "export_cancelled",
            "export_failed",
            "output_validation_failed",
        ];

        CollectionAssert.AreEquivalent(expected, contract.Errors.Select(error => error.Id).ToArray());
    }

    [TestMethod]
    public void EveryExportPlanFixtureBuildsAValidWindowsPlan()
    {
        using var document = JsonDocument.Parse(File.ReadAllText(ContractPath("fixtures", "export-plan-cases.json")));
        var cases = document.RootElement.GetProperty("cases").EnumerateArray().ToArray();
        Assert.HasCount(2, cases);

        foreach (var fixture in cases)
        {
            var input = fixture.GetProperty("input");
            var rangeElement = input.GetProperty("range");
            var output = input.GetProperty("output");
            var range = new TrimRange(
                ReadTimestamp(rangeElement.GetProperty("in")),
                ReadTimestamp(rangeElement.GetProperty("out")));
            var mode = input.GetProperty("mode").GetString() switch
            {
                "fast" => ExportMode.Fast,
                "accurate" => ExportMode.Accurate,
                var value => throw new AssertFailedException($"Unknown fixture mode: {value}"),
            };

            var plan = ExportPlan.Create(mode, range);
            plan.Validate();

            Assert.AreEqual(input.GetProperty("schemaVersion").GetInt32(), plan.SchemaVersion, fixture.GetProperty("id").GetString());
            Assert.AreEqual(output.GetProperty("container").GetString(), plan.Container);
            Assert.AreEqual(output.GetProperty("videoCodec").GetString(), CodecName(plan.VideoCodec));
            Assert.AreEqual(output.GetProperty("audioCodec").GetString(), CodecName(plan.AudioCodec));
        }
    }

    [TestMethod]
    public void EveryEditListFixtureMatchesWindowsValidation()
    {
        using var document = JsonDocument.Parse(File.ReadAllText(ContractPath("fixtures", "edit-list-cases.json")));
        var cases = document.RootElement.GetProperty("cases").EnumerateArray().ToArray();
        Assert.HasCount(2, cases);

        foreach (var fixture in cases)
        {
            var segments = fixture.GetProperty("input").GetProperty("segments").EnumerateArray()
                .Select(segment => new EditSegment(
                    StableGuid(segment.GetProperty("id").GetString()!),
                    segment.GetProperty("id").GetString()!,
                    new TrimRange(
                        ReadTimestamp(segment.GetProperty("in")),
                        ReadTimestamp(segment.GetProperty("out")))))
                .ToArray();
            var expectedValid = fixture.GetProperty("valid").GetBoolean();

            try
            {
                var editList = new EditList(segments);
                Assert.IsTrue(expectedValid, fixture.GetProperty("id").GetString());
                Assert.HasCount(segments.Length, editList.Segments);
            }
            catch (InvalidDataException)
            {
                Assert.IsFalse(expectedValid, fixture.GetProperty("id").GetString());
            }
        }
    }

    private static MediaTimestamp ReadTimestamp(JsonElement element) => new(
        element.GetProperty("value").GetInt64(),
        element.GetProperty("timescale").GetInt32());

    private static Guid StableGuid(string value)
    {
        var bytes = System.Security.Cryptography.MD5.HashData(System.Text.Encoding.UTF8.GetBytes(value));
        return new Guid(bytes);
    }

    private static string ContractPath(params string[] segments) =>
        Path.Combine([AppContext.BaseDirectory, "contracts", .. segments]);

    private static string CodecName<T>(T codec) where T : struct, Enum => codec.ToString().ToLowerInvariant();
}
