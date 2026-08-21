using System.Text.Json.Serialization;

namespace Trimlet.Media;

[JsonConverter(typeof(JsonStringEnumConverter<ExportMode>))]
public enum ExportMode
{
    Fast,
    Accurate,
}

[JsonConverter(typeof(JsonStringEnumConverter<VideoCodec>))]
public enum VideoCodec
{
    Copy,
    H264,
    Hevc,
}

[JsonConverter(typeof(JsonStringEnumConverter<AudioCodec>))]
public enum AudioCodec
{
    Copy,
    Aac,
}

public sealed record ExportPlan(
    int SchemaVersion,
    ExportMode Mode,
    TrimRange Range,
    string Container,
    VideoCodec VideoCodec,
    AudioCodec AudioCodec)
{
    public static ExportPlan Create(ExportMode mode, TrimRange range) => mode switch
    {
        ExportMode.Fast => new ExportPlan(1, mode, range, "mp4", VideoCodec.Copy, AudioCodec.Copy),
        ExportMode.Accurate => new ExportPlan(1, mode, range, "mp4", VideoCodec.H264, AudioCodec.Aac),
        _ => throw new ArgumentOutOfRangeException(nameof(mode)),
    };

    public void Validate()
    {
        if (SchemaVersion != 1)
        {
            throw new InvalidDataException("Only export-plan schema version 1 is supported.");
        }

        if (!string.Equals(Container, "mp4", StringComparison.Ordinal))
        {
            throw new InvalidDataException("The first Windows slice only produces MP4 plans.");
        }

        if (Mode == ExportMode.Fast && (VideoCodec != VideoCodec.Copy || AudioCodec != AudioCodec.Copy))
        {
            throw new InvalidDataException("Fast mode must use stream-copy codecs in schema version 1.");
        }

        if (Mode == ExportMode.Accurate && (VideoCodec == VideoCodec.Copy || AudioCodec == AudioCodec.Copy))
        {
            throw new InvalidDataException("Accurate mode must use encoding codecs in schema version 1.");
        }
    }
}
