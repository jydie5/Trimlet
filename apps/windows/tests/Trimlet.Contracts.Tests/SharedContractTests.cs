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

    private static MediaTimestamp ReadTimestamp(JsonElement element) => new(
        element.GetProperty("value").GetInt64(),
        element.GetProperty("timescale").GetInt32());

    private static string ContractPath(params string[] segments) =>
        Path.Combine([AppContext.BaseDirectory, "contracts", .. segments]);

    private static string CodecName<T>(T codec) where T : struct, Enum => codec.ToString().ToLowerInvariant();
}
