namespace Trimlet.Platform.Windows;

public static class SupportedMedia
{
    private static readonly HashSet<string> Extensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".mp4",
        ".mov",
        ".m2ts",
        ".mts",
    };

    public static IReadOnlyCollection<string> FileExtensions => Extensions;
    public static bool IsSupportedPath(string path) => Extensions.Contains(Path.GetExtension(path));
}
