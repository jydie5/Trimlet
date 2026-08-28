using Trimlet.Media;
using Trimlet.Platform.Windows;

namespace Trimlet.Media.Tests;

[TestClass]
public sealed class WindowsExportPlannerTests
{
    [TestMethod]
    public void FastPlanKeepsUnicodePathAsOneArgumentAndConvertsAc3Audio()
    {
        var metadata = Metadata(@"C:\動画 test 'quote' 🎬\source.m2ts", "h264", "ac3");
        var requested = new TrimRange(MediaTimestamp.FromSeconds(1.5), MediaTimestamp.FromSeconds(4));
        var candidate = new FastCutCandidate(
            MediaTimestamp.FromSeconds(1),
            MediaTimestamp.FromSeconds(4),
            requested.In,
            requested.Out);

        var plan = WindowsExportPlanner.Create(
            metadata,
            requested,
            ExportMode.Fast,
            @"C:\output\.clip.partial.mp4",
            0,
            "copy",
            candidate);

        Assert.AreEqual(1, plan.Arguments.Count(argument => argument == metadata.SourcePath));
        Assert.IsTrue(plan.Arguments.Contains("copy"));
        Assert.AreEqual("aac", plan.AudioEncoder);
        Assert.AreEqual(3, plan.EffectiveRange.DurationSeconds, 0.000001);
    }

    [TestMethod]
    public void AccurateInterlacedPlanUsesWindowsEncoderAndDeinterlaces()
    {
        var metadata = Metadata(@"C:\source.m2ts", "mpeg2video", "pcm_s16le", fieldOrder: "tt");
        var requested = new TrimRange(MediaTimestamp.FromSeconds(1.5), MediaTimestamp.FromSeconds(4));

        var plan = WindowsExportPlanner.Create(
            metadata,
            requested,
            ExportMode.Accurate,
            @"C:\output\.clip.partial.mp4",
            0,
            "h264_mf");

        Assert.AreEqual("h264_mf", plan.VideoEncoder);
        Assert.AreEqual("aac", plan.AudioEncoder);
        Assert.IsTrue(plan.Arguments.Any(argument => argument.StartsWith("bwdif=", StringComparison.Ordinal)));
        var arguments = plan.Arguments.ToList();
        Assert.IsLessThan(arguments.IndexOf("-ss"), arguments.IndexOf("-i"));
    }

    [TestMethod]
    public void MultiRangePlanPreservesEditOrderAndBuildsConcatStage()
    {
        var metadata = Metadata(@"C:\source.mp4", "h264", "aac");
        var ending = new EditSegment(Guid.NewGuid(), "Ending", Range(6, 7));
        var intro = new EditSegment(Guid.NewGuid(), "Intro", Range(1, 2));
        var list = new EditList([ending, intro]);
        var keyframes = new KeyframeIndex(metadata.Duration, [
            MediaTimestamp.FromSeconds(0),
            MediaTimestamp.FromSeconds(1),
            MediaTimestamp.FromSeconds(2),
            MediaTimestamp.FromSeconds(6),
            MediaTimestamp.FromSeconds(7),
            MediaTimestamp.FromSeconds(8),
        ]);

        var plan = MultiRangeExportPlanner.Create(
            metadata,
            list,
            ExportMode.Fast,
            @"C:\output\.work",
            @"C:\output\.result.partial.mp4",
            0,
            "copy",
            keyframes);

        Assert.HasCount(2, plan.SegmentPlans);
        Assert.AreEqual(6, plan.SegmentPlans[0].EffectiveRange.In.TotalSeconds, 0.000001);
        Assert.AreEqual(1, plan.SegmentPlans[1].EffectiveRange.In.TotalSeconds, 0.000001);
        Assert.IsTrue(plan.ConcatArguments.Contains("concat"));
        StringAssert.Contains(plan.ConcatListContents, "segment-000.mp4");
        Assert.AreEqual(2, plan.ExpectedDuration, 0.000001);
    }

    [TestMethod]
    public async Task ProcessRunnerTerminatesAChildProcessWhenCancelled()
    {
        var command = Environment.GetEnvironmentVariable("ComSpec");
        Assert.IsFalse(string.IsNullOrWhiteSpace(command));
        using var cancellation = new CancellationTokenSource(TimeSpan.FromMilliseconds(150));

        await Assert.ThrowsAsync<OperationCanceledException>(() =>
            ProcessRunner.RunAsync(command!, ["/d", "/c", "ping", "-n", "30", "127.0.0.1"], cancellationToken: cancellation.Token));
    }

    private static MediaMetadata Metadata(string path, string videoCodec, string audioCodec, string fieldOrder = "progressive") => new(
        path,
        "test",
        MediaTimestamp.FromSeconds(8),
        MediaTimestamp.FromSeconds(0),
        new VideoStreamInfo(
            0,
            videoCodec,
            1920,
            1080,
            new RationalFrameRate(30000, 1001),
            new RationalFrameRate(30000, 1001),
            "yuv420p",
            fieldOrder,
            "bt709",
            "bt709",
            "bt709"),
        [new AudioStreamInfo(1, 0, audioCodec, 2, "stereo", 48000, "jpn", true)],
        false,
        DateTimeOffset.UtcNow);

    private static TrimRange Range(double @in, double @out) =>
        new(MediaTimestamp.FromSeconds(@in), MediaTimestamp.FromSeconds(@out));
}
