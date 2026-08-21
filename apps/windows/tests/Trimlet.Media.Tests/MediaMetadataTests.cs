using Trimlet.Media;

namespace Trimlet.Media.Tests;

[TestClass]
public sealed class MediaMetadataTests
{
    [TestMethod]
    public void RationalFrameRatePreservesNtscRate()
    {
        var rate = RationalFrameRate.Parse("30000/1001");

        Assert.IsNotNull(rate);
        Assert.AreEqual(30000, rate.Value.Numerator);
        Assert.AreEqual(1001, rate.Value.Denominator);
        Assert.AreEqual(29.970, rate.Value.FramesPerSecond, 0.001);
    }

    [TestMethod]
    public void KeyframeCandidateExpandsToCompatibleBoundaries()
    {
        var duration = MediaTimestamp.FromSeconds(8);
        var index = new KeyframeIndex(duration, Enumerable.Range(0, 8).Select(value => MediaTimestamp.FromSeconds(value)));
        var range = new TrimRange(MediaTimestamp.FromSeconds(1.5), MediaTimestamp.FromSeconds(4.2));

        var candidate = index.FastCandidate(range);

        Assert.IsNotNull(candidate);
        Assert.AreEqual(1, candidate.Start.TotalSeconds, 0.000001);
        Assert.AreEqual(5, candidate.End.TotalSeconds, 0.000001);
    }

    [TestMethod]
    public void ProgressParsesMicrosecondsWithoutFloatingPointLocaleDependency()
    {
        var elapsed = FFmpegProgress.ElapsedFromBlock("frame=18\nout_time_us=1500000\nprogress=continue");

        Assert.AreEqual(TimeSpan.FromSeconds(1.5), elapsed);
    }
}
