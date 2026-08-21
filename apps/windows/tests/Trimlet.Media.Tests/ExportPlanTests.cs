using Trimlet.Media;

namespace Trimlet.Media.Tests;

[TestClass]
public sealed class ExportPlanTests
{
    private static readonly TrimRange Range = new(
        new MediaTimestamp(90_000, 60_000),
        new MediaTimestamp(240_000, 60_000));

    [TestMethod]
    public void FastPlanUsesStreamCopy()
    {
        var plan = ExportPlan.Create(ExportMode.Fast, Range);
        plan.Validate();

        Assert.AreEqual(VideoCodec.Copy, plan.VideoCodec);
        Assert.AreEqual(AudioCodec.Copy, plan.AudioCodec);
    }

    [TestMethod]
    public void AccuratePlanUsesEncodingCodecs()
    {
        var plan = ExportPlan.Create(ExportMode.Accurate, Range);
        plan.Validate();

        Assert.AreEqual(VideoCodec.H264, plan.VideoCodec);
        Assert.AreEqual(AudioCodec.Aac, plan.AudioCodec);
    }
}
