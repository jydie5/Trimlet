using System.IO.Compression;
using System.Security.Cryptography;

namespace Trimlet.Platform.Windows;

/// <summary>User-requested acquisition from the upstream distributor; no FFmpeg in Trimlet releases.</summary>
public static class VideoToolSetup
{
    public const string PackageName = "ffmpeg-n8.1.2-50-g1a748fe2cd-win64-lgpl-shared-8.1";
    public const string ReleaseUrl = "https://github.com/BtbN/FFmpeg-Builds/releases/tag/autobuild-2026-08-31-13-27";
    public const string DownloadUrl = "https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2026-08-31-13-27/" + PackageName + ".zip";
    public const string ArchiveHash = "e9712ffbdb03ef71bbab660c75b835bfe698ef6fad0247c76d8d394a39a3db63";
    public const long ArchiveSize = 70835150;
    private const long ExpandedLimit = 600L * 1024 * 1024;
    public static string InstallDirectory => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Trimlet", "VideoTools", PackageName);
    public static string BinDirectory => Path.Combine(InstallDirectory, "bin");

    public static bool IsInstalled
    {
        get
        {
            try
            {
                var marker = Path.Combine(InstallDirectory, ".verified");
                return File.Exists(marker) && new FileInfo(marker).Length == ArchiveHash.Length
                    && File.ReadAllText(marker) == ArchiveHash
                    && File.Exists(Path.Combine(BinDirectory, "ffmpeg.exe"))
                    && File.Exists(Path.Combine(BinDirectory, "ffprobe.exe"))
                    && File.Exists(Path.Combine(InstallDirectory, "LICENSE.txt"));
            }
            catch (IOException) { return false; }
            catch (UnauthorizedAccessException) { return false; }
        }
    }

    public static async Task InstallAsync(IProgress<double>? progress, CancellationToken cancellationToken)
    {
        if (IsInstalled) return;
        var parent = Directory.GetParent(InstallDirectory)!.FullName;
        Directory.CreateDirectory(parent);
        // Only this unique directory is removed on cancellation/failure.
        var staging = Path.Combine(parent, "setup-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(staging);
        try
        {
            var archivePath = Path.Combine(staging, "download.zip");
            using var client = new HttpClient { Timeout = TimeSpan.FromMinutes(15) };
            client.DefaultRequestHeaders.UserAgent.ParseAdd("Trimlet/0.4.0-beta.2");
            using var response = await client.GetAsync(DownloadUrl, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
            response.EnsureSuccessStatusCode();
            if (response.RequestMessage?.RequestUri?.Scheme != "https") throw new InvalidDataException("Insecure download redirect.");
            await using (var input = await response.Content.ReadAsStreamAsync(cancellationToken))
            await using (var output = new FileStream(archivePath, FileMode.CreateNew, FileAccess.Write, FileShare.None, 81920, true))
            {
                var buffer = new byte[81920];
                long total = 0;
                int count;
                while ((count = await input.ReadAsync(buffer, cancellationToken)) != 0)
                {
                    total += count;
                    if (total > ArchiveSize) throw new InvalidDataException("Unexpected download size.");
                    await output.WriteAsync(buffer.AsMemory(0, count), cancellationToken);
                    progress?.Report((double)total / ArchiveSize * 0.9);
                }
                if (total != ArchiveSize) throw new InvalidDataException("Incomplete download.");
            }
            await VerifyArchiveAsync(archivePath, cancellationToken);
            var extracted = Path.Combine(staging, "extracted");
            await Task.Run(() => ExtractChecked(archivePath, extracted, PackageName, cancellationToken), cancellationToken);
            var ready = Path.Combine(extracted, PackageName);
            foreach (var relative in new[] { "bin/ffmpeg.exe", "bin/ffprobe.exe", "LICENSE.txt" })
                if (!File.Exists(Path.Combine(ready, relative))) throw new InvalidDataException("Missing package component.");
            cancellationToken.ThrowIfCancellationRequested();
            await File.WriteAllTextAsync(Path.Combine(ready, ".verified"), ArchiveHash, cancellationToken);
            // Never overwrite an existing installation or a user's manually changed files.
            if (Directory.Exists(InstallDirectory))
            {
                if (!IsInstalled) throw new IOException("Incomplete existing installation. Choose a separate manual installation.");
            }
            else Directory.Move(ready, InstallDirectory);
            progress?.Report(1);
        }
        finally
        {
            try { Directory.Delete(staging, recursive: true); }
            catch (IOException) { }
            catch (UnauthorizedAccessException) { }
        }
    }

    public static async Task VerifyArchiveAsync(string archivePath, CancellationToken cancellationToken)
    {
        if (new FileInfo(archivePath).Length != ArchiveSize) throw new InvalidDataException("Unexpected archive size.");
        await using var stream = File.OpenRead(archivePath);
        var hash = Convert.ToHexString(await SHA256.HashDataAsync(stream, cancellationToken));
        if (!hash.Equals(ArchiveHash, StringComparison.OrdinalIgnoreCase)) throw new InvalidDataException("Download checksum mismatch.");
    }

    public static void ExtractChecked(string archivePath, string destination, string expectedRoot, CancellationToken cancellationToken)
    {
        using var archive = ZipFile.OpenRead(archivePath);
        if (archive.Entries.Count > 10000) throw new InvalidDataException("Too many files.");
        var root = Path.GetFullPath(destination) + Path.DirectorySeparatorChar;
        var names = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        long expanded = 0;
        foreach (var entry in archive.Entries)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var name = entry.FullName.Replace('\\', '/');
            if (!name.StartsWith(expectedRoot + "/", StringComparison.Ordinal)
                || name.Contains(':') || name.Split('/').Any(p => p is "." or "..")
                || ((entry.ExternalAttributes >> 16) & 0xF000) == 0xA000)
                throw new InvalidDataException("Unsafe archive path.");
            var path = Path.GetFullPath(Path.Combine(destination, name));
            if (!path.StartsWith(root, StringComparison.OrdinalIgnoreCase) || !names.Add(path))
                throw new InvalidDataException("Duplicate or escaping archive path.");
            expanded = checked(expanded + entry.Length);
            if (expanded > ExpandedLimit) throw new InvalidDataException("Archive too large.");
            if (name.EndsWith('/')) { Directory.CreateDirectory(path); continue; }
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            entry.ExtractToFile(path, overwrite: false);
        }
    }
}
