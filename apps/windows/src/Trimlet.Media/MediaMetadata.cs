namespace Trimlet.Media;

public readonly record struct RationalFrameRate
{
    public RationalFrameRate(int numerator, int denominator)
    {
        if (numerator <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(numerator));
        }

        if (denominator <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(denominator));
        }

        Numerator = numerator;
        Denominator = denominator;
    }

    public int Numerator { get; }
    public int Denominator { get; }
    public double FramesPerSecond => (double)Numerator / Denominator;
    public TimeSpan FrameDuration => TimeSpan.FromSeconds((double)Denominator / Numerator);

    public static RationalFrameRate? Parse(string? value)
    {
        var parts = value?.Split('/', StringSplitOptions.TrimEntries);
        if (parts is not { Length: 2 } ||
            !int.TryParse(parts[0], out var numerator) ||
            !int.TryParse(parts[1], out var denominator) ||
            numerator <= 0 || denominator <= 0)
        {
            return null;
        }

        return new RationalFrameRate(numerator, denominator);
    }

    public override string ToString() => $"{FramesPerSecond:0.###} fps";
}

public sealed record VideoStreamInfo(
    int StreamIndex,
    string Codec,
    int Width,
    int Height,
    RationalFrameRate? AverageFrameRate,
    RationalFrameRate? RealFrameRate,
    string PixelFormat,
    string FieldOrder,
    string? ColorPrimaries,
    string? ColorTransfer,
    string? ColorSpace)
{
    public bool IsInterlaced =>
        !string.IsNullOrWhiteSpace(FieldOrder) &&
        !string.Equals(FieldOrder, "progressive", StringComparison.OrdinalIgnoreCase) &&
        !string.Equals(FieldOrder, "unknown", StringComparison.OrdinalIgnoreCase);
}

public sealed record AudioStreamInfo(
    int StreamIndex,
    int AudioIndex,
    string Codec,
    int Channels,
    string? ChannelLayout,
    int? SampleRate,
    string? Language,
    bool IsDefault);

public sealed record MediaMetadata(
    string SourcePath,
    string FormatName,
    MediaTimestamp Duration,
    MediaTimestamp StartTimestamp,
    VideoStreamInfo Video,
    IReadOnlyList<AudioStreamInfo> AudioStreams,
    bool HasSubtitles,
    DateTimeOffset InspectedAt)
{
    public bool HasAudio => AudioStreams.Count > 0;
}
