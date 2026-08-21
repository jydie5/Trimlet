namespace Trimlet.Media;

public sealed record FastCutCandidate(
    MediaTimestamp Start,
    MediaTimestamp End,
    MediaTimestamp RequestedStart,
    MediaTimestamp RequestedEnd)
{
    public double StartDeltaSeconds => Start.TotalSeconds - RequestedStart.TotalSeconds;
    public double EndDeltaSeconds => End.TotalSeconds - RequestedEnd.TotalSeconds;
}

public sealed class KeyframeIndex
{
    public KeyframeIndex(MediaTimestamp duration, IEnumerable<MediaTimestamp> keyframes)
    {
        Duration = duration;
        Keyframes = keyframes
            .Where(value => value <= duration)
            .Distinct()
            .OrderBy(value => value)
            .ToArray();
    }

    public MediaTimestamp Duration { get; }
    public IReadOnlyList<MediaTimestamp> Keyframes { get; }

    public FastCutCandidate? FastCandidate(TrimRange range)
    {
        var start = Keyframes.LastOrDefault(value => value <= range.In);
        if (start.Timescale <= 0)
        {
            return null;
        }

        var end = Keyframes.FirstOrDefault(value => value >= range.Out);
        if (end.Timescale <= 0)
        {
            end = Duration;
        }

        return end > start
            ? new FastCutCandidate(start, end, range.In, range.Out)
            : null;
    }
}
