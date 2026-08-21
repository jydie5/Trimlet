using System.Diagnostics;
using System.Text;

namespace Trimlet.Platform.Windows;

public sealed record ProcessResult(int ExitCode, string StandardOutput, string StandardError);

public static class ProcessRunner
{
    public static async Task<ProcessResult> RunAsync(
        string executable,
        IReadOnlyList<string> arguments,
        Action<string>? standardOutputLine = null,
        CancellationToken cancellationToken = default)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = executable,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8,
        };

        foreach (var argument in arguments)
        {
            startInfo.ArgumentList.Add(argument);
        }

        using var process = new Process { StartInfo = startInfo };
        try
        {
            if (!process.Start())
            {
                throw new InvalidOperationException($"Could not start {Path.GetFileName(executable)}.");
            }
        }
        catch (Exception exception)
        {
            throw new MediaOperationException(
                "source_unreadable",
                $"{Path.GetFileName(executable)}を起動できません。設定とアクセス権を確認してください。",
                exception.ToString(),
                exception);
        }

        var output = new StringBuilder();
        var errors = new StringBuilder();
        var outputTask = ReadLinesAsync(process.StandardOutput, output, standardOutputLine);
        var errorTask = ReadLinesAsync(process.StandardError, errors, null);

        using var cancellationRegistration = cancellationToken.Register(() =>
        {
            try
            {
                if (!process.HasExited)
                {
                    process.Kill(entireProcessTree: true);
                }
            }
            catch (InvalidOperationException)
            {
                // The process exited between the check and Kill.
            }
        });

        try
        {
            await process.WaitForExitAsync(cancellationToken);
            await Task.WhenAll(outputTask, errorTask);
            cancellationToken.ThrowIfCancellationRequested();
        }
        catch (OperationCanceledException)
        {
            try
            {
                await process.WaitForExitAsync(CancellationToken.None);
                await Task.WhenAll(outputTask, errorTask);
            }
            catch
            {
                // Cancellation remains the primary result.
            }

            throw;
        }

        return new ProcessResult(process.ExitCode, output.ToString(), errors.ToString());
    }

    private static async Task ReadLinesAsync(StreamReader reader, StringBuilder destination, Action<string>? callback)
    {
        while (await reader.ReadLineAsync() is { } line)
        {
            destination.AppendLine(line);
            callback?.Invoke(line);
        }
    }
}
