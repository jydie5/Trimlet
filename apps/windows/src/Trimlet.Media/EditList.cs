namespace Trimlet.Media;

public sealed record EditSegment(Guid Id, string Name, TrimRange Range)
{
    public double DurationSeconds => Range.DurationSeconds;

    public bool Overlaps(EditSegment other) =>
        Range.In < other.Range.Out && other.Range.In < Range.Out;

    public EditSegment WithRange(TrimRange range) => this with { Range = range };

    public EditSegment WithName(string name) => this with
    {
        Name = string.IsNullOrWhiteSpace(name) ? Name : name.Trim(),
    };
}

public sealed class EditList : IEquatable<EditList>
{
    private readonly EditSegment[] _segments;

    public EditList() : this([], validate: false)
    {
    }

    public EditList(IEnumerable<EditSegment> segments) : this(segments.ToArray(), validate: true)
    {
    }

    private EditList(EditSegment[] segments, bool validate)
    {
        _segments = [.. segments];
        if (validate)
        {
            Validate();
        }
    }

    public IReadOnlyList<EditSegment> Segments => _segments;
    public bool IsEmpty => _segments.Length == 0;
    public double TotalDurationSeconds => _segments.Sum(segment => segment.DurationSeconds);

    public EditSegment? Segment(Guid id) => _segments.FirstOrDefault(segment => segment.Id == id);

    public EditList Add(EditSegment segment, MediaTimestamp? sourceDuration = null)
    {
        ValidateSegment(segment, null, sourceDuration);
        return new EditList([.. _segments, segment], validate: false);
    }

    public EditList Update(EditSegment segment, MediaTimestamp? sourceDuration = null)
    {
        var index = Array.FindIndex(_segments, existing => existing.Id == segment.Id);
        if (index < 0)
        {
            throw new KeyNotFoundException("The clip was not found.");
        }

        ValidateSegment(segment, segment.Id, sourceDuration);
        var updated = _segments.ToArray();
        updated[index] = segment;
        return new EditList(updated, validate: false);
    }

    public EditList Remove(Guid id)
    {
        if (!_segments.Any(segment => segment.Id == id))
        {
            throw new KeyNotFoundException("The clip was not found.");
        }

        return new EditList(_segments.Where(segment => segment.Id != id).ToArray(), validate: false);
    }

    public EditList Move(Guid id, int destinationIndex)
    {
        var sourceIndex = Array.FindIndex(_segments, segment => segment.Id == id);
        if (sourceIndex < 0)
        {
            throw new KeyNotFoundException("The clip was not found.");
        }

        var reordered = _segments.ToList();
        var segment = reordered[sourceIndex];
        reordered.RemoveAt(sourceIndex);
        reordered.Insert(Math.Clamp(destinationIndex, 0, reordered.Count), segment);
        return new EditList([.. reordered], validate: false);
    }

    public void Validate(MediaTimestamp? sourceDuration = null)
    {
        var identifiers = new HashSet<Guid>();
        foreach (var segment in _segments)
        {
            if (!identifiers.Add(segment.Id))
            {
                throw new InvalidDataException("Clip identifiers must be unique.");
            }

            ValidateSegment(segment, segment.Id, sourceDuration);
        }
    }

    private void ValidateSegment(EditSegment segment, Guid? replacing, MediaTimestamp? sourceDuration)
    {
        if (segment.Id == Guid.Empty)
        {
            throw new InvalidDataException("A clip must have a stable identifier.");
        }

        if (string.IsNullOrWhiteSpace(segment.Name))
        {
            throw new InvalidDataException("A clip must have a name.");
        }

        if (sourceDuration is { } duration)
        {
            segment.Range.ValidateAgainst(duration);
        }

        if (_segments.Any(existing => existing.Id != replacing && existing.Overlaps(segment)))
        {
            throw new InvalidDataException("The clip overlaps an existing retained source range.");
        }
    }

    public bool Equals(EditList? other) =>
        other is not null && _segments.SequenceEqual(other._segments);

    public override bool Equals(object? obj) => obj is EditList other && Equals(other);

    public override int GetHashCode()
    {
        var hash = new HashCode();
        foreach (var segment in _segments)
        {
            hash.Add(segment);
        }

        return hash.ToHashCode();
    }
}
