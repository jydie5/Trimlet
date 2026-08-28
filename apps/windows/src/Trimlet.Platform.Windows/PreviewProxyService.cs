using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using Trimlet.Media;

namespace Trimlet.Platform.Windows;

public sealed record PreviewProxyProgress(double Fraction, TimeSpan Elapsed);

public sealed record PreviewProxyResult(string Path, long SizeBytes, bool ReusedCache);

public sealed record PreviewProxyPlan(
    string CachePath,
    string PartialPath,
    IReadOnlyList<string> Arguments,
    string VideoEncoder);

public sealed class PreviewProxyService
{
    private readonly FFmpegToolchain toolchain;
    private readonly MediaInspector inspector;
    private readonly string cacheDirectory;

    public PreviewProxyService(
        FFmpegToolchain toolchain,
        MediaInspector inspector,
        string? cacheDirectory = null)
    {
        this.toolchain = toolchain;
        this.inspector = inspector;
        this.cacheDirectory = cacheDirectory ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Trimlet",
            "Cache",
            "Proxies");
    }

    public string CacheDirectory => cacheDirectory;

    public static bool PreferProxyForPath(string path) =>
        Path.GetExtension(path).Equals(".m2ts", StringComparison.OrdinalIgnoreCase) ||
        Path.GetExtension(path).Equals(".mts", StringComparison.OrdinalIgnoreCase);

    public async Task<PreviewProxyResult> GetOrCreateAsync(
        MediaMetadata metadata,
        IProgress<PreviewProxyProgress>? progress = null,
        CancellationToken cancellationToken = default)
    {
        Directory.CreateDirectory(cacheDirectory);
        var cachePath = Path.Combine(cacheDirectory, CacheIdentifier(metadata) + ".mp4");
        if (await IsUsableCacheAsync(cachePath, metadata.Duration.TotalSeconds, cancellationToken))
        {
            var cached = new FileInfo(cachePath);
            progress?.Report(new PreviewProxyProgress(1, metadata.Duration.ToTimeSpan()));
            return new PreviewProxyResult(cachePath, cached.Length, ReusedCache: true);
        }

        DeleteIfExists(cachePath);
        var encoder = await toolchain.SelectH264EncoderAsync(cancellationToken);
        var plan = CreatePlan(metadata, cachePath, encoder);
        try
        {
            var result = await ProcessRunner.RunAsync(
                toolchain.FFmpegPath,
                plan.Arguments,
                line =>
                {
                    if (FFmpegProgress.ElapsedFromBlock(line) is not { } elapsed)
                    {
                        return;
                    }

                    progress?.Report(new PreviewProxyProgress(
                        Math.Clamp(elapsed.TotalSeconds / metadata.Duration.TotalSeconds, 0, 1),
                        elapsed));
                },
                cancellationToken);
            if (result.ExitCode != 0)
            {
                throw new MediaOperationException(
                    "proxy_failed",
                    "プレビュー用プロキシを生成できませんでした。診断内容を確認してください。",
                    result.StandardError);
            }

            var inspected = await inspector.InspectAsync(plan.PartialPath, cancellationToken);
            if (inspected.Duration.TotalSeconds <= 0 ||
                Math.Abs(inspected.Duration.TotalSeconds - metadata.Duration.TotalSeconds) > Math.Max(1, metadata.Duration.TotalSeconds * 0.02))
            {
                throw new MediaOperationException(
                    "proxy_failed",
                    "生成したプロキシの長さを検証できませんでした。",
                    $"Expected {metadata.Duration.TotalSeconds:0.###} seconds; got {inspected.Duration.TotalSeconds:0.###} seconds.");
            }

            File.Move(plan.PartialPath, plan.CachePath, overwrite: false);
            var created = new FileInfo(plan.CachePath);
            progress?.Report(new PreviewProxyProgress(1, inspected.Duration.ToTimeSpan()));
            return new PreviewProxyResult(plan.CachePath, created.Length, ReusedCache: false);
        }
        catch
        {
            DeleteIfExists(plan.PartialPath);
            throw;
        }
    }

    public static PreviewProxyPlan CreatePlan(MediaMetadata metadata, string cachePath, string videoEncoder)
    {
        var partialPath = cachePath + $".{Guid.NewGuid():N}.partial.mp4";
        var filters = metadata.Video.IsInterlaced
            ? "bwdif=mode=send_frame:parity=auto:deint=all,scale=w='min(1280,iw)':h=-2"
            : "scale=w='min(1280,iw)':h=-2";
        var arguments = new List<string>
        {
            "-hide_banner", "-loglevel", "error", "-nostats", "-y",
            "-progress", "pipe:1", "-stats_period", "0.1",
            "-i", metadata.SourcePath,
            "-map", $"0:{metadata.Video.StreamIndex}",
            "-map", "0:a:0?",
            "-sn", "-dn",
            "-vf", filters,
            "-c:v", videoEncoder,
        };

        if (videoEncoder.Equals("libx264", StringComparison.OrdinalIgnoreCase))
        {
            arguments.AddRange(["-crf", "24", "-preset", "veryfast"]);
        }
        else
        {
            arguments.AddRange(["-b:v", "4M", "-maxrate", "5M", "-bufsize", "10M"]);
        }

        arguments.AddRange([
            "-pix_fmt", "yuv420p",
            "-c:a", "aac", "-b:a", "128k", "-ac", "2",
            "-map_metadata", "-1",
            "-movflags", "+faststart",
            partialPath,
        ]);
        return new PreviewProxyPlan(cachePath, partialPath, arguments, videoEncoder);
    }

    public static string CacheIdentifier(MediaMetadata metadata)
    {
        var file = new FileInfo(metadata.SourcePath);
        var fingerprint = string.Join('|', [
            Path.GetFullPath(metadata.SourcePath).ToUpperInvariant(),
            file.Exists ? file.Length.ToString(CultureInfo.InvariantCulture) : "0",
            file.Exists ? file.LastWriteTimeUtc.Ticks.ToString(CultureInfo.InvariantCulture) : "0",
            metadata.Video.StreamIndex.ToString(CultureInfo.InvariantCulture),
            metadata.Video.Codec,
            $"{metadata.Video.Width}x{metadata.Video.Height}",
            metadata.Video.PixelFormat,
            metadata.Video.FieldOrder,
        ]);
        return Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(fingerprint)));
    }

    private async Task<bool> IsUsableCacheAsync(
        string path,
        double expectedDuration,
        CancellationToken cancellationToken)
    {
        if (!File.Exists(path) || new FileInfo(path).Length == 0)
        {
            return false;
        }

        try
        {
            var cached = await inspector.InspectAsync(path, cancellationToken);
            return cached.Duration.TotalSeconds > 0 &&
                Math.Abs(cached.Duration.TotalSeconds - expectedDuration) <= Math.Max(1, expectedDuration * 0.02);
        }
        catch (MediaOperationException)
        {
            return false;
        }
    }

    private static void DeleteIfExists(string path)
    {
        try
        {
            if (File.Exists(path))
            {
                File.Delete(path);
            }
        }
        catch (IOException)
        {
        }
        catch (UnauthorizedAccessException)
        {
        }
    }
}
