using Trimlet.Media;
using Trimlet.Platform.Windows;

namespace Trimlet.Media.Tests;

[TestClass]
public sealed class PreviewProxyServiceTests
{
    [TestMethod]
    [DataRow("video.m2ts", true)]
    [DataRow("video.MTS", true)]
    [DataRow("video.mp4", false)]
    [DataRow("video.mov", false)]
    public void PrefersProxyForTransportStreamExtensions(string path, bool expected)
    {
        Assert.AreEqual(expected, PreviewProxyService.PreferProxyForPath(path));
    }

    [TestMethod]
    public void PlanUsesArgumentArrayAndNeverTargetsTheSource()
    {
        var metadata = Metadata(@"C:\source 日本語 'quote' 🎬.m2ts", interlaced: true);
        var plan = PreviewProxyService.CreatePlan(metadata, @"C:\cache\proxy.mp4", "libx264");

        CollectionAssert.Contains(plan.Arguments.ToArray(), metadata.SourcePath);
        Assert.AreEqual(plan.PartialPath, plan.Arguments[^1]);
        Assert.IsFalse(string.Equals(metadata.SourcePath, plan.PartialPath, StringComparison.OrdinalIgnoreCase));
        StringAssert.Contains(plan.Arguments.Single(argument => argument.Contains("scale=", StringComparison.Ordinal)), "bwdif");
        CollectionAssert.Contains(plan.Arguments.ToArray(), "veryfast");
    }

    [TestMethod]
    public void CacheIdentityChangesWhenSourcePropertiesChange()
    {
        var source = Path.GetTempFileName();
        try
        {
            var first = Metadata(source, interlaced: false);
            var firstId = PreviewProxyService.CacheIdentifier(first);
            File.AppendAllText(source, "changed");
            File.SetLastWriteTimeUtc(source, DateTime.UtcNow.AddSeconds(2));
            var secondId = PreviewProxyService.CacheIdentifier(first);

            Assert.AreNotEqual(firstId, secondId);
            Assert.AreEqual(64, firstId.Length);
        }
        finally
        {
            File.Delete(source);
        }
    }

    private static MediaMetadata Metadata(string path, bool interlaced) => new(
        path,
        "MPEG-TS",
        MediaTimestamp.FromSeconds(10),
        MediaTimestamp.FromSeconds(0),
        new VideoStreamInfo(
            0,
            "h264",
            1920,
            1080,
            new RationalFrameRate(30, 1),
            new RationalFrameRate(30, 1),
            "yuv420p",
            interlaced ? "tt" : "progressive",
            null,
            null,
            null),
        [new AudioStreamInfo(1, 0, "ac3", 2, "stereo", 48_000, "jpn", true)],
        HasSubtitles: false,
        DateTimeOffset.UtcNow);
}
