using System.Text.Json;
using System.Text.Json.Serialization;

namespace Trimlet.Media;

public sealed record ProjectSource(string FileName, string PathHint, long? SizeBytes = null, DateTimeOffset? ModifiedAt = null);
public sealed record ProjectAudio(int StreamIndex, string? CodecName = null, string? Language = null, string? Title = null);
public sealed record ProjectSettings(string ExportMode, ProjectAudio? Audio = null);
public sealed record ProjectTime(long Value, int Timescale)
{
    [JsonIgnore] public MediaTimestamp Timestamp => new(Value, Timescale);
    public static ProjectTime From(MediaTimestamp time) => new(time.Value, time.Timescale);
}
public sealed record ProjectSegment(Guid Id, ProjectTime In, ProjectTime Out, string? Name = null);
public sealed record ProjectEdits(ProjectSegment[] Segments);
public sealed record TrimletProject(int SchemaVersion, ProjectSource Source, ProjectEdits EditList, ProjectSettings Settings)
{
    public const int MaximumBytes = 8 * 1024 * 1024;
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow,
        RespectRequiredConstructorParameters = true,
        RespectNullableAnnotations = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
        WriteIndented = true,
    };

    public Trimlet.Media.EditList ToEditList() => new(EditList.Segments.Select((s, i) =>
        new EditSegment(s.Id, string.IsNullOrWhiteSpace(s.Name) ? $"Clip {i + 1}" : s.Name,
            new TrimRange(s.In.Timestamp, s.Out.Timestamp))));

    public void Validate(MediaTimestamp? duration = null)
    {
        if (SchemaVersion != 1 || Source is null || EditList?.Segments is null || Settings is null)
            throw new InvalidDataException("Invalid project version or structure.");
        if (string.IsNullOrEmpty(Source.FileName) || !IsPortablePath(Source.PathHint) || Source.SizeBytes < 0)
            throw new InvalidDataException("Invalid project source reference.");
        if (Settings.ExportMode is not ("fast" or "accurate") || Settings.Audio?.StreamIndex < 0)
            throw new InvalidDataException("Invalid project settings.");
        if (EditList.Segments.Any(s => s is null || s.In is null || s.Out is null))
            throw new InvalidDataException("Invalid project segment.");
        ToEditList().Validate(duration);
    }

    public static bool IsPortablePath(string? path) => !string.IsNullOrEmpty(path)
        && !path.StartsWith('/') && !path.Contains('\\') && !path.Contains('\0')
        && !(path.Length >= 2 && char.IsAsciiLetter(path[0]) && path[1] == ':');

    public static TrimletProject Decode(ReadOnlySpan<byte> bytes)
    {
        if (bytes.Length > MaximumBytes) throw new InvalidDataException("Project exceeds 8 MiB.");
        var project = JsonSerializer.Deserialize<TrimletProject>(bytes, Options)
            ?? throw new InvalidDataException("Empty project.");
        project.Validate();
        return project;
    }

    public byte[] Encode()
    {
        Validate();
        var bytes = JsonSerializer.SerializeToUtf8Bytes(this, Options);
        if (bytes.Length > MaximumBytes) throw new InvalidDataException("Project exceeds 8 MiB.");
        return bytes;
    }
}
