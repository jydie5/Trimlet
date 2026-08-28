namespace Trimlet.Media;

public sealed class FrameTimestampIndex
{
    private const double ComparisonToleranceSeconds = 0.000_001;
    private readonly MediaTimestamp[] timestamps;

    public FrameTimestampIndex(MediaTimestamp duration, IEnumerable<MediaTimestamp> timestamps)
    {
        Duration = duration;
        this.timestamps = timestamps
            .Where(timestamp => timestamp <= duration)
            .Distinct()
            .OrderBy(timestamp => timestamp)
            .ToArray();
    }

    public MediaTimestamp Duration { get; }
    public IReadOnlyList<MediaTimestamp> Timestamps => timestamps;

    public MediaTimestamp Step(MediaTimestamp position, int frameCount)
    {
        if (frameCount == 0 || timestamps.Length == 0)
        {
            return Clamp(position);
        }

        var seconds = Math.Clamp(position.TotalSeconds, 0, Duration.TotalSeconds);
        if (frameCount > 0)
        {
            var firstAfter = FirstIndexAtOrAfter(seconds + ComparisonToleranceSeconds);
            if (firstAfter >= timestamps.Length)
            {
                return Duration;
            }

            return timestamps[Math.Min(firstAfter + frameCount - 1, timestamps.Length - 1)];
        }

        var firstAtPosition = FirstIndexAtOrAfter(seconds - ComparisonToleranceSeconds);
        var lastBefore = firstAtPosition - 1;
        if (lastBefore < 0)
        {
            return new MediaTimestamp(0, Duration.Timescale);
        }

        return timestamps[Math.Max(0, lastBefore - Math.Abs(frameCount) + 1)];
    }

    private int FirstIndexAtOrAfter(double seconds)
    {
        var low = 0;
        var high = timestamps.Length;
        while (low < high)
        {
            var middle = low + (high - low) / 2;
            if (timestamps[middle].TotalSeconds < seconds)
            {
                low = middle + 1;
            }
            else
            {
                high = middle;
            }
        }

        return low;
    }

    private MediaTimestamp Clamp(MediaTimestamp position)
    {
        if (position > Duration)
        {
            return Duration;
        }

        return position;
    }
}
