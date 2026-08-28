using System.Globalization;
using Trimlet.Media;

namespace Trimlet.Platform.Windows;

public sealed record FFmpegCommandPlan(
    IReadOnlyList<string> Arguments,
    TrimRange EffectiveRange,
    string VideoEncoder,
    string AudioEncoder,
    bool ExpectsAudio);

public static class WindowsExportPlanner
{
    public static FFmpegCommandPlan Create(
        MediaMetadata metadata,
        TrimRange requestedRange,
        ExportMode mode,
        string temporaryOutputPath,
        int selectedAudioIndex,
        string accurateVideoEncoder,
        FastCutCandidate? fastCandidate = null)
    {
        var effectiveRange = mode == ExportMode.Fast && fastCandidate is not null
            ? new TrimRange(fastCandidate.Start, fastCandidate.End)
            : requestedRange;
        var selectedAudio = metadata.AudioStreams.FirstOrDefault(stream => stream.AudioIndex == selectedAudioIndex)
            ?? metadata.AudioStreams.FirstOrDefault();

        var arguments = new List<string>
        {
            "-hide_banner",
            "-loglevel", "error",
            "-nostats",
            "-y",
            "-progress", "pipe:1",
            "-stats_period", "0.1",
        };

        if (mode == ExportMode.Fast)
        {
            arguments.AddRange(["-ss", Time(effectiveRange.In.TotalSeconds), "-i", metadata.SourcePath]);
        }
        else
        {
            arguments.AddRange(["-i", metadata.SourcePath, "-ss", Time(effectiveRange.In.TotalSeconds)]);
        }

        arguments.AddRange([
            "-t", Time(effectiveRange.Duration.TotalSeconds),
            "-map", $"0:{metadata.Video.StreamIndex}",
        ]);

        if (selectedAudio is not null)
        {
            arguments.AddRange(["-map", $"0:{selectedAudio.StreamIndex}"]);
        }

        arguments.Add("-sn");

        string videoEncoder;
        string audioEncoder;
        if (mode == ExportMode.Fast)
        {
            videoEncoder = "copy";
            arguments.AddRange(["-c:v", "copy"]);
            if (selectedAudio is null)
            {
                audioEncoder = "none";
            }
            else if (string.Equals(selectedAudio.Codec, "aac", StringComparison.OrdinalIgnoreCase))
            {
                audioEncoder = "copy";
                arguments.AddRange(["-c:a", "copy"]);
            }
            else
            {
                audioEncoder = "aac";
                arguments.AddRange(["-c:a", "aac", "-b:a", AudioBitrate(selectedAudio.Channels)]);
            }
        }
        else
        {
            videoEncoder = accurateVideoEncoder;
            audioEncoder = selectedAudio is null ? "none" : "aac";
            arguments.AddRange(["-c:v", accurateVideoEncoder]);
            if (string.Equals(accurateVideoEncoder, "libx264", StringComparison.OrdinalIgnoreCase))
            {
                arguments.AddRange(["-crf", "20", "-preset", "medium"]);
            }
            else
            {
                var bitrate = VideoBitrate(metadata.Video);
                arguments.AddRange(["-b:v", bitrate, "-maxrate", bitrate, "-bufsize", DoubleBitrate(bitrate)]);
            }

            if (metadata.Video.IsInterlaced)
            {
                arguments.AddRange(["-vf", "bwdif=mode=send_frame:parity=auto:deint=all"]);
            }

            arguments.AddRange(["-pix_fmt", "yuv420p"]);
            if (selectedAudio is not null)
            {
                arguments.AddRange(["-c:a", "aac", "-b:a", AudioBitrate(selectedAudio.Channels)]);
            }
        }

        arguments.AddRange([
            "-map_metadata", "0",
            "-map_chapters", "0",
            "-avoid_negative_ts", "make_zero",
            "-movflags", "+faststart+use_metadata_tags",
            temporaryOutputPath,
        ]);

        return new FFmpegCommandPlan(
            arguments,
            effectiveRange,
            videoEncoder,
            audioEncoder,
            selectedAudio is not null);
    }

    private static string Time(double seconds) => seconds.ToString("0.000000", CultureInfo.InvariantCulture);

    private static string AudioBitrate(int channels) => channels > 2 ? "384k" : "256k";

    private static string VideoBitrate(VideoStreamInfo video)
    {
        var fps = video.AverageFrameRate?.FramesPerSecond ?? 30;
        var bitsPerSecond = video.Width * (double)video.Height * fps * 0.075;
        var megabits = Math.Clamp(bitsPerSecond / 1_000_000, 2, 35);
        return $"{Math.Round(megabits, MidpointRounding.AwayFromZero):0}M";
    }

    private static string DoubleBitrate(string bitrate)
    {
        var value = int.Parse(bitrate.TrimEnd('M'), CultureInfo.InvariantCulture);
        return $"{value * 2}M";
    }
}
