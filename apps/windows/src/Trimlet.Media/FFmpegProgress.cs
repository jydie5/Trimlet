namespace Trimlet.Media;

public static class FFmpegProgress
{
    public static TimeSpan? ElapsedFromBlock(string text)
    {
        long? microseconds = null;
        foreach (var rawLine in text.Split('\n'))
        {
            var line = rawLine.Trim();
            var separator = line.IndexOf('=');
            if (separator <= 0 || separator == line.Length - 1)
            {
                continue;
            }

            var key = line[..separator];
            if ((key == "out_time_us" || key == "out_time_ms") &&
                long.TryParse(line[(separator + 1)..], out var value))
            {
                microseconds = Math.Max(0, value);
            }
        }

        return microseconds is { } elapsed
            ? TimeSpan.FromTicks(elapsed * 10)
            : null;
    }
}
