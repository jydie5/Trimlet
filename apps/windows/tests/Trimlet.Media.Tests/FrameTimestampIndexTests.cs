using Trimlet.Media;

namespace Trimlet.Media.Tests;

[TestClass]
public sealed class FrameTimestampIndexTests
{
    private static readonly MediaTimestamp Duration = MediaTimestamp.FromSeconds(1);

    [TestMethod]
    public void StepsThroughIrregularPresentationTimestamps()
    {
        var index = new FrameTimestampIndex(Duration, [
            Time(0), Time(0.033), Time(0.071), Time(0.100), Time(0.155), Time(0.188),
        ]);

        Assert.AreEqual(Time(0.071), index.Step(Time(0.033), 1));
        Assert.AreEqual(Time(0.155), index.Step(Time(0.033), 3));
        Assert.AreEqual(Time(0.033), index.Step(Time(0.155), -3));
    }

    [TestMethod]
    public void ClampsAtSourceBoundaries()
    {
        var index = new FrameTimestampIndex(Duration, [Time(0), Time(0.4), Time(0.8)]);

        Assert.AreEqual(Time(0), index.Step(Time(0), -1));
        Assert.AreEqual(Duration, index.Step(Time(0.8), 10));
    }

    [TestMethod]
    public void SortsDeduplicatesAndDropsOutOfRangeFrames()
    {
        var index = new FrameTimestampIndex(Duration, [Time(0.4), Time(0.1), Time(0.4), Time(1.2)]);

        CollectionAssert.AreEqual(new[] { Time(0.1), Time(0.4) }, index.Timestamps.ToArray());
    }

    private static MediaTimestamp Time(double seconds) => MediaTimestamp.FromSeconds(seconds);
}
