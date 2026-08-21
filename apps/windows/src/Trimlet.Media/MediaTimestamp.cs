using System.Numerics;

namespace Trimlet.Media;

public readonly record struct MediaTimestamp : IComparable<MediaTimestamp>
{
    public MediaTimestamp(long value, int timescale)
    {
        if (value < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(value), "A media timestamp cannot be negative.");
        }

        if (timescale <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(timescale), "Timescale must be positive.");
        }

        Value = value;
        Timescale = timescale;
    }

    public long Value { get; }
    public int Timescale { get; }
    public double TotalSeconds => (double)Value / Timescale;

    public static MediaTimestamp FromTimeSpan(TimeSpan value) =>
        new(value.Ticks, checked((int)TimeSpan.TicksPerSecond));

    public static MediaTimestamp FromSeconds(double value, int timescale = 1_000_000)
    {
        if (!double.IsFinite(value) || value < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(value), "A media timestamp must be finite and non-negative.");
        }

        if (timescale <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(timescale), "Timescale must be positive.");
        }

        return new MediaTimestamp(checked((long)Math.Round(value * timescale)), timescale);
    }

    public TimeSpan ToTimeSpan() => TimeSpan.FromSeconds(TotalSeconds);

    public int CompareTo(MediaTimestamp other)
    {
        var left = (BigInteger)Value * other.Timescale;
        var right = (BigInteger)other.Value * Timescale;
        return left.CompareTo(right);
    }

    public static bool operator <(MediaTimestamp left, MediaTimestamp right) => left.CompareTo(right) < 0;
    public static bool operator >(MediaTimestamp left, MediaTimestamp right) => left.CompareTo(right) > 0;
    public static bool operator <=(MediaTimestamp left, MediaTimestamp right) => left.CompareTo(right) <= 0;
    public static bool operator >=(MediaTimestamp left, MediaTimestamp right) => left.CompareTo(right) >= 0;
}
