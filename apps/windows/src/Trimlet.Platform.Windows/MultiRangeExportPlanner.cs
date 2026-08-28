using Trimlet.Media;

namespace Trimlet.Platform.Windows;

public sealed record MultiRangeExportPlan(
    IReadOnlyList<FFmpegCommandPlan> SegmentPlans,
    IReadOnlyList<string> SegmentPaths,
    IReadOnlyList<string> ConcatArguments,
    string ConcatListPath,
    IReadOnlyList<TrimRange> EffectiveRanges,
    double ExpectedDuration,
    string VideoEncoder,
    string AudioEncoder,
    bool ExpectsAudio)
{
    public string ConcatListContents => string.Join(
        Environment.NewLine,
        SegmentPaths.Select(path => $"file '{EscapeConcatPath(path)}'")) + Environment.NewLine;

    private static string EscapeConcatPath(string path) => path.Replace("'", "'\\''", StringComparison.Ordinal);
}

public static class MultiRangeExportPlanner
{
    public static MultiRangeExportPlan Create(
        MediaMetadata metadata,
        EditList editList,
        ExportMode mode,
        string operationDirectory,
        string incompleteDestination,
        int selectedAudioIndex,
        string accurateVideoEncoder,
        KeyframeIndex? keyframes)
    {
        if (editList.IsEmpty)
        {
            throw new InvalidDataException("The editing sequence is empty.");
        }

        editList.Validate(metadata.Duration);
        var plans = new List<FFmpegCommandPlan>();
        var paths = new List<string>();
        foreach (var (segment, index) in editList.Segments.Select((segment, index) => (segment, index)))
        {
            var candidate = mode == ExportMode.Fast ? keyframes?.FastCandidate(segment.Range) : null;
            if (mode == ExportMode.Fast && candidate is null)
            {
                throw new InvalidDataException($"No Fast candidate is available for clip {segment.Id}.");
            }

            var segmentPath = Path.Combine(operationDirectory, $"segment-{index:000}.mp4");
            paths.Add(segmentPath);
            plans.Add(WindowsExportPlanner.Create(
                metadata,
                segment.Range,
                mode,
                segmentPath,
                selectedAudioIndex,
                accurateVideoEncoder,
                candidate));
        }

        var concatListPath = Path.Combine(operationDirectory, "segments.ffconcat");
        var concatArguments = new List<string>
        {
            "-hide_banner", "-loglevel", "error", "-nostats", "-y",
            "-progress", "pipe:1", "-stats_period", "0.1",
            "-f", "concat", "-safe", "0", "-i", concatListPath,
            "-c", "copy", "-movflags", "+faststart", incompleteDestination,
        };
        var effectiveRanges = plans.Select(plan => plan.EffectiveRange).ToArray();

        return new MultiRangeExportPlan(
            plans,
            paths,
            concatArguments,
            concatListPath,
            effectiveRanges,
            effectiveRanges.Sum(range => range.DurationSeconds),
            plans[0].VideoEncoder,
            plans[0].AudioEncoder,
            plans.Any(plan => plan.ExpectsAudio));
    }
}
