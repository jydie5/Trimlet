using Trimlet.Media;

namespace Trimlet.Media.Tests;

[TestClass]
public sealed class MediaTimestampTests
{
    [TestMethod]
    public void ComparesEquivalentRationalTimestampsWithoutFloatingPoint()
    {
        var ntsc = new MediaTimestamp(30_000, 30_000);
        var milliseconds = new MediaTimestamp(1_000, 1_000);

        Assert.AreEqual(0, ntsc.CompareTo(milliseconds));
    }

    [TestMethod]
    public void ComparisonDoesNotOverflowLongMultiplication()
    {
        var left = new MediaTimestamp(long.MaxValue - 1, int.MaxValue);
        var right = new MediaTimestamp(long.MaxValue - 2, int.MaxValue - 1);

        Assert.IsTrue(left < right);
    }

    [TestMethod]
    public void RejectsInvalidTimescale()
    {
        Assert.ThrowsExactly<ArgumentOutOfRangeException>(() => new MediaTimestamp(0, 0));
    }
}
