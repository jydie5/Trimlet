using System.Diagnostics;
using System.Globalization;
using Trimlet.Media;

namespace Trimlet.Platform.Windows;

public sealed record ExportProgress(double Fraction, TimeSpan Elapsed, string Stage);

public sealed record ExportResult(
    string OutputPath,
    string DiagnosticsPath,
    TimeSpan Duration,
    string VideoEncoder,
    string AudioEncoder,
    TrimRange EffectiveRange);

public sealed class ExportService(FFmpegToolchain toolchain, MediaInspector inspector)
{
    public async Task<ExportResult> ExportAsync(
        MediaMetadata metadata,
        TrimRange requestedRange,
        ExportMode mode,
        string outputDirectory,
        int selectedAudioIndex,
        FastCutCandidate? fastCandidate,
        IProgress<ExportProgress>? progress = null,
        CancellationToken cancellationToken = default)
    {
        requestedRange.ValidateAgainst(metadata.Duration);
        var directory = Path.GetFullPath(outputDirectory);
        Directory.CreateDirectory(directory);

        var outputPath = UniqueOutputPath(directory, Path.GetFileNameWithoutExtension(metadata.SourcePath) + "-trimmed");
        if (string.Equals(Path.GetFullPath(metadata.SourcePath), outputPath, StringComparison.OrdinalIgnoreCase))
        {
            throw new MediaOperationException("output_conflict", "元動画と同じ場所には書き出せません。別の保存先を選択してください。");
        }

        EnsureFreeSpace(directory, metadata, requestedRange);
        var temporaryPath = Path.Combine(directory, $".{Path.GetFileNameWithoutExtension(outputPath)}.{Guid.NewGuid():N}.partial.mp4");
        var diagnosticsPath = CreateDiagnosticsPath();
        var accurateEncoder = mode == ExportMode.Accurate
            ? await toolchain.SelectH264EncoderAsync(cancellationToken)
            : "copy";
        var plan = WindowsExportPlanner.Create(
            metadata,
            requestedRange,
            mode,
            temporaryPath,
            selectedAudioIndex,
            accurateEncoder,
            fastCandidate);

        var progressLines = new List<string>();
        try
        {
            progress?.Report(new ExportProgress(0, TimeSpan.Zero, "exporting"));
            var result = await ProcessRunner.RunAsync(
                toolchain.FFmpegPath,
                plan.Arguments,
                line =>
                {
                    progressLines.Add(line);
                    if (FFmpegProgress.ElapsedFromBlock(line) is not { } elapsed)
                    {
                        return;
                    }

                    var fraction = Math.Clamp(elapsed.TotalSeconds / plan.EffectiveRange.Duration.TotalSeconds, 0, 1);
                    progress?.Report(new ExportProgress(fraction, elapsed, "exporting"));
                },
                cancellationToken);

            await WriteDiagnosticsAsync(diagnosticsPath, plan, result, progressLines, cancellationToken);
            if (result.ExitCode != 0)
            {
                throw new MediaOperationException(
                    "export_failed",
                    "FFmpegの書き出しに失敗しました。診断ログを確認するか、正確モードを試してください。",
                    result.StandardError);
            }

            progress?.Report(new ExportProgress(0.98, plan.EffectiveRange.Duration.ToTimeSpan(), "validating"));
            var validation = await ValidateOutputAsync(
                temporaryPath,
                plan.EffectiveRange.Duration.TotalSeconds,
                plan.ExpectsAudio,
                mode,
                metadata.Video.AverageFrameRate,
                cancellationToken);
            if (!validation.IsValid)
            {
                throw new MediaOperationException("output_validation_failed", validation.Message, validation.Diagnostics);
            }

            File.Move(temporaryPath, outputPath, overwrite: false);
            progress?.Report(new ExportProgress(1, validation.Duration, "completed"));
            return new ExportResult(
                outputPath,
                diagnosticsPath,
                validation.Duration,
                plan.VideoEncoder,
                plan.AudioEncoder,
                plan.EffectiveRange);
        }
        catch (OperationCanceledException)
        {
            DeleteIfExists(temporaryPath);
            throw;
        }
        catch
        {
            DeleteIfExists(temporaryPath);
            throw;
        }
    }

    public static void RevealInExplorer(string path)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = "explorer.exe",
            UseShellExecute = false,
        };
        startInfo.ArgumentList.Add("/select,");
        startInfo.ArgumentList.Add(Path.GetFullPath(path));
        Process.Start(startInfo);
    }

    private async Task<(bool IsValid, string Message, string Diagnostics, TimeSpan Duration)> ValidateOutputAsync(
        string outputPath,
        double expectedDuration,
        bool expectsAudio,
        ExportMode mode,
        RationalFrameRate? frameRate,
        CancellationToken cancellationToken)
    {
        try
        {
            var output = await inspector.InspectAsync(outputPath, cancellationToken);
            if (expectsAudio && !output.HasAudio)
            {
                return (false, "元動画にある音声が出力されていません。", "Audio stream missing.", TimeSpan.Zero);
            }

            var actual = output.Duration.TotalSeconds;
            var tolerance = mode == ExportMode.Accurate
                ? Math.Max(0.2, (frameRate?.FrameDuration.TotalSeconds ?? 0.05) * 2)
                : Math.Max(5, expectedDuration);
            if (actual <= 0.001 || Math.Abs(actual - expectedDuration) > tolerance)
            {
                return (
                    false,
                    "出力時間が指定範囲から大きく外れています。完成ファイルとして確定しませんでした。",
                    $"Expected {expectedDuration.ToString("0.000000", CultureInfo.InvariantCulture)} seconds; got {actual.ToString("0.000000", CultureInfo.InvariantCulture)} seconds.",
                    output.Duration.ToTimeSpan());
            }

            return (true, "映像、音声、出力時間を確認しました。", string.Empty, output.Duration.ToTimeSpan());
        }
        catch (MediaOperationException exception)
        {
            return (false, "出力ファイルを検証できませんでした。完成ファイルとして確定しませんでした。", exception.Diagnostics ?? exception.Message, TimeSpan.Zero);
        }
    }

    private static string UniqueOutputPath(string directory, string baseName)
    {
        var safeBaseName = string.Concat(baseName.Select(character =>
            Path.GetInvalidFileNameChars().Contains(character) ? '_' : character)).Trim();
        if (string.IsNullOrWhiteSpace(safeBaseName))
        {
            safeBaseName = "trimlet-output";
        }

        for (var suffix = 0; suffix < 10_000; suffix++)
        {
            var fileName = suffix == 0 ? $"{safeBaseName}.mp4" : $"{safeBaseName}-{suffix}.mp4";
            var candidate = Path.Combine(directory, fileName);
            if (!File.Exists(candidate))
            {
                return candidate;
            }
        }

        throw new MediaOperationException("output_conflict", "保存先に同名ファイルが多すぎます。別のフォルダーを選択してください。");
    }

    private static void EnsureFreeSpace(string directory, MediaMetadata metadata, TrimRange range)
    {
        var root = Path.GetPathRoot(directory);
        if (string.IsNullOrEmpty(root))
        {
            return;
        }

        var drive = new DriveInfo(root);
        var sourceBytesPerSecond = new FileInfo(metadata.SourcePath).Length / Math.Max(metadata.Duration.TotalSeconds, 0.001);
        var estimatedBytes = Math.Max(256L * 1024 * 1024, (long)(sourceBytesPerSecond * range.Duration.TotalSeconds * 1.25));
        if (drive.AvailableFreeSpace < estimatedBytes)
        {
            throw new MediaOperationException(
                "insufficient_space",
                $"保存先の空き容量が不足しています。少なくとも約{estimatedBytes / 1024 / 1024:N0} MB空けてください。");
        }
    }

    private static string CreateDiagnosticsPath()
    {
        var directory = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Trimlet",
            "Logs");
        Directory.CreateDirectory(directory);
        return Path.Combine(directory, $"export-{DateTime.Now:yyyyMMdd-HHmmss}-{Guid.NewGuid():N}.log");
    }

    private static async Task WriteDiagnosticsAsync(
        string path,
        FFmpegCommandPlan plan,
        ProcessResult result,
        IReadOnlyList<string> progressLines,
        CancellationToken cancellationToken)
    {
        var redactedArguments = plan.Arguments.Select(argument =>
            Path.IsPathFullyQualified(argument) ? $"<path:{Path.GetFileName(argument)}>" : argument);
        var text = string.Join(Environment.NewLine, [
            $"Trimlet export {DateTimeOffset.Now:O}",
            $"Encoder: {plan.VideoEncoder} / {plan.AudioEncoder}",
            $"Arguments: {string.Join(' ', redactedArguments)}",
            $"Exit code: {result.ExitCode}",
            "",
            "Progress:",
            string.Join(Environment.NewLine, progressLines),
            "",
            "Standard error:",
            result.StandardError,
        ]);
        await File.WriteAllTextAsync(path, text, cancellationToken);
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
            // The incomplete suffix prevents a failed cleanup from looking finished.
        }
        catch (UnauthorizedAccessException)
        {
            // The incomplete suffix prevents a failed cleanup from looking finished.
        }
    }
}
