using Trimlet.Media;

namespace Trimlet.Media.Tests;

[TestClass]
public sealed class TimelineGeometryTests
{
    [TestMethod]
    public void UpperLaneAndFillAlwaysSeekAndTinyGripsStayExclusive()
    {
        var geometry = new TimelineGeometry(1048, 100);
        Assert.AreEqual(24d, geometry.X(0));
        Assert.AreEqual(1024d, geometry.X(100));
        Assert.AreEqual(TimelineTarget.Seek, geometry.Hit(geometry.X(50) - 1, 20, 50, 50.001));
        Assert.AreEqual(TimelineTarget.In, geometry.Hit(geometry.X(50) - 1, 50, 50, 50.001));
        Assert.AreEqual(TimelineTarget.Seek, geometry.Hit(geometry.X(50), 50, 50, 50.001));
        Assert.AreEqual(TimelineTarget.Out, geometry.Hit(geometry.X(50.001), 50, 50, 50.001));
        Assert.AreEqual(TimelineTarget.In, geometry.Hit(0, 50, 0, 100));
        Assert.AreEqual(TimelineTarget.Out, geometry.Hit(1047, 50, 0, 100));
        Assert.AreEqual(TimelineTarget.Seek, geometry.Hit(double.NaN, 50, 0, 100));
    }

    [TestMethod]
    public void ZoomTranslationDoesNotJumpOrExposeOffscreenHandles()
    {
        var geometry = new TimelineGeometry(1048, 100, 40, 10);
        Assert.AreEqual(44.123, geometry.Translate(44.123, 0));
        Assert.AreEqual(45.123, geometry.Translate(44.123, 100), 0.000001);
        Assert.AreEqual(0d, geometry.Translate(44, -10000));
        Assert.AreEqual(100d, geometry.Translate(44, 10000));
        Assert.AreEqual(TimelineTarget.Seek, geometry.Hit(23, 50, 30, 80));
        Assert.AreEqual(45d, geometry.Time(524));
    }
}
