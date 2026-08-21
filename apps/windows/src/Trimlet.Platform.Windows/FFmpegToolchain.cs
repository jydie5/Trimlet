using System.Diagnostics;

namespace Trimlet.Platform.Windows;

public sealed record FFmpegToolchain(string FFmpegPath, string FFprobePath)
{
    public static FFmpegToolchain? Discover()
    {
        var ffmpeg = FindExecutable("TRIMLET_FFMPEG", "ffmpeg.exe");
        var ffprobe = FindExecutable("TRIMLET_FFPROBE", "ffprobe.exe");
        return ffmpeg is not null && ffprobe is not null
            ? new FFmpegToolchain(ffmpeg, ffprobe)
            : null;
    }

    public async Task<string> VersionAsync(CancellationToken cancellationToken = default)
    {
        var result = await ProcessRunner.RunAsync(
            FFmpegPath,
            ["-version"],
            cancellationToken: cancellationToken);
        return result.StandardOutput.Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries).FirstOrDefault()
            ?? Path.GetFileName(FFmpegPath);
    }

    public async Task<string> SelectH264EncoderAsync(CancellationToken cancellationToken = default)
    {
        var result = await ProcessRunner.RunAsync(
            FFmpegPath,
            ["-hide_banner", "-encoders"],
            cancellationToken: cancellationToken);
        var output = result.StandardOutput + result.StandardError;
        string[] priority = ["h264_mf", "h264_nvenc", "h264_qsv", "h264_amf", "libx264", "libopenh264"];
        var diagnostics = new List<string> { output };
        foreach (var encoder in priority.Where(encoder => output.Contains(encoder, StringComparison.OrdinalIgnoreCase)))
        {
            var probe = await ProcessRunner.RunAsync(
                FFmpegPath,
                [
                    "-hide_banner", "-loglevel", "error",
                    "-f", "lavfi",
                    "-i", "color=size=64x64:rate=1:duration=0.1",
                    "-frames:v", "1",
                    "-an",
                    "-c:v", encoder,
                    "-f", "null",
                    "-",
                ],
                cancellationToken: cancellationToken);
            diagnostics.Add($"{encoder}: exit {probe.ExitCode}{Environment.NewLine}{probe.StandardError}");
            if (probe.ExitCode == 0)
            {
                return encoder;
            }
        }

        throw new MediaOperationException(
            "unsupported_streams",
            "FFmpegに実行可能なH.264エンコーダーがありません。別のFFmpeg構成を使用してください。",
            string.Join(Environment.NewLine, diagnostics));
    }

    private static string? FindExecutable(string environmentName, string fileName)
    {
        var explicitPath = Environment.GetEnvironmentVariable(environmentName);
        if (!string.IsNullOrWhiteSpace(explicitPath) && File.Exists(explicitPath))
        {
            return Path.GetFullPath(explicitPath);
        }

        var besideApp = Path.Combine(AppContext.BaseDirectory, fileName);
        if (File.Exists(besideApp))
        {
            return besideApp;
        }

        foreach (var directory in (Environment.GetEnvironmentVariable("PATH") ?? string.Empty)
                     .Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            try
            {
                var candidate = Path.Combine(directory.Trim('"'), fileName);
                if (File.Exists(candidate))
                {
                    return Path.GetFullPath(candidate);
                }
            }
            catch (Exception) when (directory.IndexOfAny(Path.GetInvalidPathChars()) >= 0)
            {
                // Ignore malformed PATH entries and continue discovery.
            }
        }

        return null;
    }
}
