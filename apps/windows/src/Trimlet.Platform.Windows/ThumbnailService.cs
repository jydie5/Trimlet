using System.Globalization;
using Trimlet.Media;

namespace Trimlet.Platform.Windows;

public sealed class ThumbnailService : IDisposable
{
    private readonly FFmpegToolchain _toolchain;
    private readonly string _cacheDirectory;

    public ThumbnailService(FFmpegToolchain toolchain)
    {
        _toolchain = toolchain;
        _cacheDirectory = Path.Combine(Path.GetTempPath(), "Trimlet", "Thumbnails", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_cacheDirectory);
    }

    public async Task<string?> GenerateAsync(
        string sourcePath,
        EditSegment segment,
        CancellationToken cancellationToken = default)
    {
        var outputPath = Path.Combine(_cacheDirectory, $"{segment.Id:N}.jpg");
        var seek = Math.Max(0, segment.Range.In.TotalSeconds + Math.Min(0.1, segment.DurationSeconds / 4));
        var result = await ProcessRunner.RunAsync(
            _toolchain.FFmpegPath,
            [
                "-hide_banner", "-loglevel", "error", "-y",
                "-ss", seek.ToString("0.000000", CultureInfo.InvariantCulture),
                "-i", sourcePath,
                "-frames:v", "1",
                "-vf", "scale=240:-2",
                "-q:v", "4",
                outputPath,
            ],
            cancellationToken: cancellationToken);

        return result.ExitCode == 0 && File.Exists(outputPath) ? outputPath : null;
    }

    public void Dispose()
    {
        try
        {
            if (Directory.Exists(_cacheDirectory))
            {
                Directory.Delete(_cacheDirectory, recursive: true);
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
