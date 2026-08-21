namespace Trimlet.Media;

public readonly record struct TrimRange
{
    public TrimRange(MediaTimestamp @in, MediaTimestamp @out)
    {
        if (@out <= @in)
        {
            throw new ArgumentException("OUT must be later than IN.", nameof(@out));
        }

        In = @in;
        Out = @out;
    }

    public MediaTimestamp In { get; }
    public MediaTimestamp Out { get; }
    public MediaTimestamp Duration => MediaTimestamp.FromSeconds(DurationSeconds);
    public double DurationSeconds => Out.TotalSeconds - In.TotalSeconds;

    public void ValidateAgainst(MediaTimestamp sourceDuration)
    {
        if (In < new MediaTimestamp(0, 1) || Out > sourceDuration)
        {
            throw new ArgumentOutOfRangeException(nameof(sourceDuration), "The trim range must stay within the source duration.");
        }
    }

    public TrimRange Clamp(MediaTimestamp sourceStart, MediaTimestamp sourceEnd)
    {
        if (sourceEnd <= sourceStart)
        {
            throw new ArgumentException("The source end must be later than its start.", nameof(sourceEnd));
        }

        var clampedIn = In < sourceStart ? sourceStart : In;
        var clampedOut = Out > sourceEnd ? sourceEnd : Out;
        return new TrimRange(clampedIn, clampedOut);
    }
}
