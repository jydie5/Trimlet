using Trimlet.Media;

namespace Trimlet.Media.Tests;

[TestClass]
public sealed class TrimRangeTests
{
    [TestMethod]
    public void OutBoundaryIsExclusiveForDuration()
    {
        var range = new TrimRange(
            new MediaTimestamp(90_000, 60_000),
            new MediaTimestamp(240_000, 60_000));

        Assert.AreEqual(2.5, range.DurationSeconds, 0.000_001);
    }

    [TestMethod]
    public void ClampKeepsRangeInsideSource()
    {
        var range = new TrimRange(
            new MediaTimestamp(1, 1),
            new MediaTimestamp(12, 1));

        var clamped = range.Clamp(
            new MediaTimestamp(2, 1),
            new MediaTimestamp(10, 1));

        Assert.AreEqual(2L, clamped.In.Value);
        Assert.AreEqual(10L, clamped.Out.Value);
    }

    [TestMethod]
    public void RejectsEmptyRange()
    {
        var timestamp = new MediaTimestamp(1, 1);
        Assert.ThrowsExactly<ArgumentException>(() => new TrimRange(timestamp, timestamp));
    }
}
