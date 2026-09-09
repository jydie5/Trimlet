using Trimlet.Media;

namespace Trimlet.Platform.Windows;

public static class ProjectStore
{
    public static async Task<TrimletProject> ReadAsync(string path)
    {
        await using var input = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read);
        if (input.Length > TrimletProject.MaximumBytes) throw new InvalidDataException("Project exceeds 8 MiB.");
        var bytes = new byte[checked((int)input.Length)];
        await input.ReadExactlyAsync(bytes);
        return TrimletProject.Decode(bytes);
    }

    public static async Task SaveAsync(string path, TrimletProject project)
    {
        var bytes = project.Encode();
        var target = Path.GetFullPath(path);
        var temporary = Path.Combine(Path.GetDirectoryName(target)!, $".trimlet-{Guid.NewGuid():N}.tmp");
        try
        {
            await using (var output = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            {
                await output.WriteAsync(bytes);
                output.Flush(flushToDisk: true);
            }
            if (File.Exists(target)) File.Replace(temporary, target, null);
            else File.Move(temporary, target);
        }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }

    public static ProjectSource Capture(string mediaPath, string projectPath)
    {
        var file = new FileInfo(mediaPath);
        var hint = Path.GetRelativePath(Path.GetDirectoryName(Path.GetFullPath(projectPath))!, file.FullName).Replace('\\', '/');
        if (!TrimletProject.IsPortablePath(hint))
            throw new InvalidDataException("Save the project on the same drive as its source video.");
        return new(file.Name, hint, file.Length, file.LastWriteTimeUtc);
    }

    public static string Resolve(ProjectSource source, string projectPath) =>
        Path.GetFullPath(Path.Combine(Path.GetDirectoryName(Path.GetFullPath(projectPath))!, source.PathHint));

    public static bool Matches(ProjectSource source, string path)
    {
        var file = new FileInfo(path);
        return file.Exists && (source.SizeBytes is null || source.SizeBytes == file.Length)
            && (source.ModifiedAt is null || Math.Abs((file.LastWriteTimeUtc - source.ModifiedAt.Value.UtcDateTime).TotalSeconds) <= 2);
    }
}
