using Trimlet.Media;
using Trimlet.Platform.Windows;
using System.Security.Cryptography;
using System.Text.RegularExpressions;

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
            "-f", "lavfi", "-i", "color=c=red:size=640x360:rate=30:duration=8",
            "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000:duration=8,volume=0.05",
            "-f", "lavfi", "-i", "sine=frequency=880:sample_rate=48000:duration=8,volume=0.8",
            "-map", "0:v:0", "-map", "1:a:0", "-map", "2:a:0",
            "-vf", "drawbox=color=green:t=fill:enable='between(t,2.666,5.333)',drawbox=color=blue:t=fill:enable='gte(t,5.333)'",
            "-c:v", "libx264", "-preset", "ultrafast",
            "-g", "30", "-keyint_min", "30", "-sc_threshold", "0",
            "-c:a", "aac", "-shortest",
            "-metadata:s:a:0", "language=eng", "-disposition:a:0", "default",
            "-metadata:s:a:1", "language=jpn", "-disposition:a:1", "0",
            sourcePath,
        ]);
    Require(generation.ExitCode == 0 && File.Exists(sourcePath), $"Synthetic source generation failed: {generation.StandardError}");
    var sourceHash = await Sha256Async(sourcePath);

    var inspector = new MediaInspector(toolchain);
    var metadata = await inspector.InspectAsync(sourcePath);
    Require(metadata.Video.Width == 640 && metadata.Video.Height == 360, "Inspection did not preserve source dimensions.");
    Require(metadata.AudioStreams.Count == 2, "Inspection did not find both generated audio streams.");
    Require(metadata.AudioStreams[0].Language == "eng" && metadata.AudioStreams[1].Language == "jpn", "Inspection lost audio language metadata.");
    Require(Math.Abs(metadata.Duration.TotalSeconds - 8) < 0.2, "Inspection returned the wrong source duration.");

    var keyframes = await inspector.InspectKeyframesAsync(metadata);
    Require(keyframes.Keyframes.Count >= 7, "Keyframe inspection returned too few keyframes.");

    var vfrPath = Path.Combine(checkRoot, "variable frame rate.mp4");
    var vfrGeneration = await ProcessRunner.RunAsync(
        toolchain.FFmpegPath,
        [
            "-hide_banner", "-loglevel", "error", "-y",
            "-f", "lavfi", "-i", "testsrc2=size=320x180:rate=30:duration=3",
            "-vf", "select='if(lt(t,1),1,not(mod(n,2)))'",
            "-fps_mode", "vfr", "-c:v", "libx264", "-preset", "ultrafast",
            vfrPath,
        ]);
    Require(vfrGeneration.ExitCode == 0 && File.Exists(vfrPath), $"VFR source generation failed: {vfrGeneration.StandardError}");
    var vfrMetadata = await inspector.InspectAsync(vfrPath);
    var frameTimestamps = await inspector.InspectFrameTimestampsAsync(vfrMetadata);
    Require(frameTimestamps.Timestamps.Count >= 40, $"VFR inspection returned too few frame timestamps: {frameTimestamps.Timestamps.Count}.");
    var frameIntervals = frameTimestamps.Timestamps
        .Zip(frameTimestamps.Timestamps.Skip(1), (left, right) => right.TotalSeconds - left.TotalSeconds)
        .ToArray();
    Require(frameIntervals.Any(interval => interval < 0.05) && frameIntervals.Any(interval => interval > 0.05), "VFR inspection did not preserve irregular presentation intervals.");
    var firstLongGap = Array.FindIndex(frameIntervals, interval => interval > 0.05);
    Require(firstLongGap >= 0, "VFR fixture has no long frame interval.");
    var steppedTimestamp = frameTimestamps.Step(frameTimestamps.Timestamps[firstLongGap], 1);
    Require(Math.Abs(steppedTimestamp.TotalSeconds - frameTimestamps.Timestamps[firstLongGap + 1].TotalSeconds) < 0.000001, "VFR stepping did not use the next presentation timestamp.");

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
        1,
        keyframes);
    Require(File.Exists(multiAccurate.OutputPath), "Multi-range Accurate export was not finalized.");
    Require(Math.Abs(multiAccurate.Duration.TotalSeconds - editList.TotalDurationSeconds) < 0.35, "Multi-range Accurate duration missed the edit-list total.");
    Require(multiAccurate.SequenceRanges?.Count == 3, "Multi-range Accurate result lost its segment order.");
    Require(Math.Abs(multiAccurate.SequenceRanges![0].In.TotalSeconds - 6.2) < 0.001, "Reordered first segment was not preserved.");
    await RequireSequenceColorsAsync(toolchain, multiAccurate.OutputPath, multiAccurate.SequenceRanges!, ["blue", "red", "green"], checkRoot);
    Require(await MeanVolumeAsync(toolchain, multiAccurate.OutputPath) > -30, "Multi-range Accurate output did not use the selected non-default audio stream.");

    var multiFast = await exportService.ExportEditListAsync(
        metadata,
        editList,
        ExportMode.Fast,
        checkRoot,
        1,
        keyframes);
    Require(File.Exists(multiFast.OutputPath), "Multi-range Fast export was not finalized.");
    Require(multiFast.VideoEncoder == "copy", "Multi-range Fast export re-encoded video.");
    Require(multiFast.SequenceRanges?.Count == 3, "Multi-range Fast result lost its candidates.");
    await RequireSequenceColorsAsync(toolchain, multiFast.OutputPath, multiFast.SequenceRanges!, ["blue", "red", "green"], checkRoot);
    Require(await MeanVolumeAsync(toolchain, multiFast.OutputPath) > -30, "Multi-range Fast output did not use the selected non-default audio stream.");

    var transportPath = Path.Combine(checkRoot, "transport source 日本語.m2ts");
    var transportGeneration = await ProcessRunner.RunAsync(
        toolchain.FFmpegPath,
        [
            "-hide_banner", "-loglevel", "error", "-y",
            "-i", sourcePath,
            "-map", "0:v:0", "-map", "0:a:1",
            "-c:v", "copy", "-c:a", "ac3", "-f", "mpegts",
            transportPath,
        ]);
    Require(transportGeneration.ExitCode == 0 && File.Exists(transportPath), $"M2TS source generation failed: {transportGeneration.StandardError}");
    var transportHash = await Sha256Async(transportPath);
    var transportMetadata = await inspector.InspectAsync(transportPath);
    var proxyCache = Path.Combine(checkRoot, "proxy cache");
    var proxyService = new PreviewProxyService(toolchain, inspector, proxyCache);
    var proxy = await proxyService.GetOrCreateAsync(transportMetadata);
    Require(File.Exists(proxy.Path) && proxy.SizeBytes > 0, "Preview proxy was not finalized.");
    Require(!proxy.ReusedCache, "The first preview proxy unexpectedly reported a cache hit.");
    var reusedProxy = await proxyService.GetOrCreateAsync(transportMetadata);
    Require(reusedProxy.ReusedCache && reusedProxy.Path == proxy.Path, "A valid preview proxy was not reused.");
    Require(await Sha256Async(transportPath) == transportHash, "Preview proxy generation changed the source.");
    Require(!Directory.EnumerateFiles(proxyCache, "*.partial.mp4").Any(), "An incomplete preview proxy remained.");
    Require(await Sha256Async(sourcePath) == sourceHash, "The source file changed during export.");
    Require(!Directory.EnumerateFiles(checkRoot, "*.partial.mp4").Any(), "An incomplete export file remained.");
    Require(!Directory.EnumerateDirectories(checkRoot, "*.partial").Any(), "A multi-range operation directory remained.");

    Console.WriteLine($"PASS: inspected {metadata.Video.Codec} {metadata.Video.Width}x{metadata.Video.Height} with {keyframes.Keyframes.Count} keyframes.");
    Console.WriteLine($"PASS: VFR frame stepping used {frameTimestamps.Timestamps.Count} presentation timestamps with irregular intervals.");
    Console.WriteLine($"PASS: Fast output {fast.Duration.TotalSeconds:0.000}s ({fast.VideoEncoder}/{fast.AudioEncoder}).");
    Console.WriteLine($"PASS: Accurate output {accurate.Duration.TotalSeconds:0.000}s ({accurate.VideoEncoder}/{accurate.AudioEncoder}).");
    Console.WriteLine($"PASS: Multi-range Accurate output {multiAccurate.Duration.TotalSeconds:0.000}s in reordered edit-list order.");
    Console.WriteLine($"PASS: Multi-range Fast output {multiFast.Duration.TotalSeconds:0.000}s with {multiFast.SequenceRanges!.Count} candidates.");
    Console.WriteLine("PASS: Reordered output colors and the selected non-default audio stream were verified in both modes.");
    Console.WriteLine($"PASS: M2TS/AC-3 preview proxy {proxy.SizeBytes / 1024.0 / 1024.0:0.0} MB was validated and reused without changing the source.");
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

static async Task RequireSequenceColorsAsync(
    FFmpegToolchain toolchain,
    string path,
    IReadOnlyList<TrimRange> ranges,
    IReadOnlyList<string> expectedColors,
    string scratchDirectory)
{
    Require(ranges.Count == expectedColors.Count, "The color expectation count does not match the exported sequence.");
    var sequenceOffset = 0d;
    for (var index = 0; index < ranges.Count; index++)
    {
        var sampleAt = sequenceOffset + ranges[index].DurationSeconds / 2;
        var actual = await DominantColorAtAsync(toolchain, path, sampleAt, scratchDirectory, index);
        Require(
            actual == expectedColors[index],
            $"Sequence item {index + 1} was {actual}, expected {expectedColors[index]} at {sampleAt:0.###}s.");
        sequenceOffset += ranges[index].DurationSeconds;
    }
}

static async Task<string> DominantColorAtAsync(
    FFmpegToolchain toolchain,
    string path,
    double seconds,
    string scratchDirectory,
    int index)
{
    var samplePath = Path.Combine(scratchDirectory, $"sample-{Path.GetFileNameWithoutExtension(path)}-{index}.ppm");
    var result = await ProcessRunner.RunAsync(
        toolchain.FFmpegPath,
        [
            "-hide_banner", "-loglevel", "error", "-y",
            "-ss", seconds.ToString("0.000000", System.Globalization.CultureInfo.InvariantCulture),
            "-i", path,
            "-vf", "scale=1:1:flags=area,format=rgb24",
            "-frames:v", "1", "-f", "image2", "-vcodec", "ppm",
            samplePath,
        ]);
    Require(result.ExitCode == 0 && File.Exists(samplePath), $"Color sample failed: {result.StandardError}");
    var bytes = await File.ReadAllBytesAsync(samplePath);
    Require(bytes.Length >= 3, "Color sample was empty.");
    var red = bytes[^3];
    var green = bytes[^2];
    var blue = bytes[^1];
    return red >= green && red >= blue ? "red" : green >= blue ? "green" : "blue";
}

static async Task<double> MeanVolumeAsync(FFmpegToolchain toolchain, string path)
{
    var result = await ProcessRunner.RunAsync(
        toolchain.FFmpegPath,
        [
            "-hide_banner", "-nostats", "-i", path,
            "-map", "0:a:0", "-af", "volumedetect", "-f", "null", "-",
        ]);
    Require(result.ExitCode == 0, $"Audio analysis failed: {result.StandardError}");
    var match = Regex.Match(result.StandardError, @"mean_volume:\s*(-?[0-9]+(?:\.[0-9]+)?)\s*dB", RegexOptions.IgnoreCase);
    Require(match.Success, "Audio analysis did not report mean volume.");
    return double.Parse(match.Groups[1].Value, System.Globalization.CultureInfo.InvariantCulture);
}
