using Trimlet.Media;
using Trimlet.Platform.Windows;
using System.Security.Cryptography;

var requireTools = args.Contains("--require-tools", StringComparer.OrdinalIgnoreCase);
var toolchain = FFmpegToolchain.Discover();
if (toolchain is null)
{
    if (requireTools)
    {
        Console.Error.WriteLine("FAIL: ffmpeg and ffprobe are required but were not discovered.");
        return 1;
    }

    Console.WriteLine("SKIP: ffmpeg and ffprobe were not discovered.");
    return 0;
}

var checkRoot = Path.Combine(Path.GetTempPath(), $"Trimlet 日本語 'quote' 🎬 {Guid.NewGuid():N}");
Directory.CreateDirectory(checkRoot);
try
{
    Console.WriteLine(await toolchain.VersionAsync());
    var sourcePath = Path.Combine(checkRoot, "synthetic source 日本語 🎬.mp4");
    var generation = await ProcessRunner.RunAsync(
        toolchain.FFmpegPath,
        [
            "-hide_banner", "-loglevel", "error", "-y",
            "-f", "lavfi", "-i", "testsrc2=size=640x360:rate=30:duration=8",
            "-f", "lavfi", "-i", "sine=frequency=880:sample_rate=48000:duration=8",
            "-c:v", "libx264", "-preset", "ultrafast",
            "-g", "30", "-keyint_min", "30", "-sc_threshold", "0",
            "-c:a", "aac", "-shortest",
            sourcePath,
        ]);
    Require(generation.ExitCode == 0 && File.Exists(sourcePath), $"Synthetic source generation failed: {generation.StandardError}");
    var sourceHash = await Sha256Async(sourcePath);

    var inspector = new MediaInspector(toolchain);
    var metadata = await inspector.InspectAsync(sourcePath);
    Require(metadata.Video.Width == 640 && metadata.Video.Height == 360, "Inspection did not preserve source dimensions.");
    Require(metadata.HasAudio, "Inspection did not find the generated audio stream.");
    Require(Math.Abs(metadata.Duration.TotalSeconds - 8) < 0.2, "Inspection returned the wrong source duration.");

    var keyframes = await inspector.InspectKeyframesAsync(metadata);
    Require(keyframes.Keyframes.Count >= 7, "Keyframe inspection returned too few keyframes.");

    var exportService = new ExportService(toolchain, inspector);
    var requested = new TrimRange(MediaTimestamp.FromSeconds(1.5), MediaTimestamp.FromSeconds(4));
    var candidate = keyframes.FastCandidate(requested);
    Require(candidate is not null, "No Fast candidate was produced.");

    var fast = await exportService.ExportAsync(
        metadata,
        requested,
        ExportMode.Fast,
        checkRoot,
        0,
        candidate);
    Require(File.Exists(fast.OutputPath), "Fast export was not finalized.");
    Require(fast.VideoEncoder == "copy", "Fast export re-encoded video.");

    var accurate = await exportService.ExportAsync(
        metadata,
        requested,
        ExportMode.Accurate,
        checkRoot,
        0,
        null);
    Require(File.Exists(accurate.OutputPath), "Accurate export was not finalized.");
    Require(Math.Abs(accurate.Duration.TotalSeconds - requested.DurationSeconds) < 0.25, "Accurate export duration missed the selected range.");
    Require(!string.Equals(fast.OutputPath, accurate.OutputPath, StringComparison.OrdinalIgnoreCase), "Existing output was overwritten instead of receiving a unique name.");

    var editList = new EditList([
        new EditSegment(Guid.NewGuid(), "Ending", Range(6.2, 7.0)),
        new EditSegment(Guid.NewGuid(), "Intro", Range(0.2, 1.0)),
        new EditSegment(Guid.NewGuid(), "Middle", Range(3.2, 4.0)),
    ]);
    var multiAccurate = await exportService.ExportEditListAsync(
        metadata,
        editList,
        ExportMode.Accurate,
        checkRoot,
        0,
        keyframes);
    Require(File.Exists(multiAccurate.OutputPath), "Multi-range Accurate export was not finalized.");
    Require(Math.Abs(multiAccurate.Duration.TotalSeconds - editList.TotalDurationSeconds) < 0.35, "Multi-range Accurate duration missed the edit-list total.");
    Require(multiAccurate.SequenceRanges?.Count == 3, "Multi-range Accurate result lost its segment order.");
    Require(Math.Abs(multiAccurate.SequenceRanges![0].In.TotalSeconds - 6.2) < 0.001, "Reordered first segment was not preserved.");

    var multiFast = await exportService.ExportEditListAsync(
        metadata,
        editList,
        ExportMode.Fast,
        checkRoot,
        0,
        keyframes);
    Require(File.Exists(multiFast.OutputPath), "Multi-range Fast export was not finalized.");
    Require(multiFast.VideoEncoder == "copy", "Multi-range Fast export re-encoded video.");
    Require(multiFast.SequenceRanges?.Count == 3, "Multi-range Fast result lost its candidates.");
    Require(await Sha256Async(sourcePath) == sourceHash, "The source file changed during export.");
    Require(!Directory.EnumerateFiles(checkRoot, "*.partial.mp4").Any(), "An incomplete export file remained.");
    Require(!Directory.EnumerateDirectories(checkRoot, "*.partial").Any(), "A multi-range operation directory remained.");

    Console.WriteLine($"PASS: inspected {metadata.Video.Codec} {metadata.Video.Width}x{metadata.Video.Height} with {keyframes.Keyframes.Count} keyframes.");
    Console.WriteLine($"PASS: Fast output {fast.Duration.TotalSeconds:0.000}s ({fast.VideoEncoder}/{fast.AudioEncoder}).");
    Console.WriteLine($"PASS: Accurate output {accurate.Duration.TotalSeconds:0.000}s ({accurate.VideoEncoder}/{accurate.AudioEncoder}).");
    Console.WriteLine($"PASS: Multi-range Accurate output {multiAccurate.Duration.TotalSeconds:0.000}s in reordered edit-list order.");
    Console.WriteLine($"PASS: Multi-range Fast output {multiFast.Duration.TotalSeconds:0.000}s with {multiFast.SequenceRanges!.Count} candidates.");
    Console.WriteLine("PASS: Unicode, spaces, quotes, temporary finalization, and output validation completed.");
    return 0;
}
finally
{
    if (Directory.Exists(checkRoot))
    {
        Directory.Delete(checkRoot, recursive: true);
    }
}

static void Require(bool condition, string message)
{
    if (!condition)
    {
        throw new InvalidOperationException(message);
    }
}

static async Task<string> Sha256Async(string path)
{
    await using var stream = File.OpenRead(path);
    return Convert.ToHexString(await SHA256.HashDataAsync(stream));
}

static TrimRange Range(double @in, double @out) =>
    new(MediaTimestamp.FromSeconds(@in), MediaTimestamp.FromSeconds(@out));
