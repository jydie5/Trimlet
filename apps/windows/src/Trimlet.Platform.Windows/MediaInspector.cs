using System.Globalization;
using System.Text.Json;
using Trimlet.Media;

namespace Trimlet.Platform.Windows;

public sealed class MediaInspector(FFmpegToolchain toolchain)
{
    public async Task<MediaMetadata> InspectAsync(string sourcePath, CancellationToken cancellationToken = default)
    {
        var fullPath = Path.GetFullPath(sourcePath);
        if (!File.Exists(fullPath))
        {
            throw new MediaOperationException("source_unreadable", "元動画が見つかりません。移動または削除されていないか確認してください。");
        }

        var result = await ProcessRunner.RunAsync(
            toolchain.FFprobePath,
            [
                "-v", "error",
                "-show_format",
                "-show_streams",
                "-of", "json",
                fullPath,
            ],
            cancellationToken: cancellationToken);

        if (result.ExitCode != 0)
        {
            throw new MediaOperationException(
                "source_unreadable",
                "動画を解析できません。ファイルが壊れていないか、対応形式かを確認してください。",
                result.StandardError);
        }

        try
        {
            using var document = JsonDocument.Parse(result.StandardOutput);
            var root = document.RootElement;
            var streams = root.GetProperty("streams").EnumerateArray().ToArray();
            var videoElement = streams.FirstOrDefault(stream => GetString(stream, "codec_type") == "video");
            if (videoElement.ValueKind == JsonValueKind.Undefined)
            {
                throw new MediaOperationException("unsupported_streams", "映像ストリームが見つかりません。別の動画を選択してください。");
            }

            var format = root.TryGetProperty("format", out var formatElement) ? formatElement : default;
            var durationSeconds = ParseDouble(GetString(format, "duration"))
                ?? ParseDouble(GetString(videoElement, "duration"))
                ?? throw new MediaOperationException("source_unreadable", "動画の長さを取得できません。");
            var startSeconds = Math.Max(0, ParseDouble(GetString(videoElement, "start_time")) ?? 0);

            var video = new VideoStreamInfo(
                GetInt(videoElement, "index"),
                GetString(videoElement, "codec_name") ?? "unknown",
                GetInt(videoElement, "width"),
                GetInt(videoElement, "height"),
                RationalFrameRate.Parse(GetString(videoElement, "avg_frame_rate")),
                RationalFrameRate.Parse(GetString(videoElement, "r_frame_rate")),
                GetString(videoElement, "pix_fmt") ?? "unknown",
                GetString(videoElement, "field_order") ?? "unknown",
                GetString(videoElement, "color_primaries"),
                GetString(videoElement, "color_transfer"),
                GetString(videoElement, "color_space"));

            var audio = new List<AudioStreamInfo>();
            foreach (var stream in streams.Where(stream => GetString(stream, "codec_type") == "audio"))
            {
                var tags = stream.TryGetProperty("tags", out var tagsElement) ? tagsElement : default;
                var disposition = stream.TryGetProperty("disposition", out var dispositionElement) ? dispositionElement : default;
                audio.Add(new AudioStreamInfo(
                    GetInt(stream, "index"),
                    audio.Count,
                    GetString(stream, "codec_name") ?? "unknown",
                    GetInt(stream, "channels"),
                    GetString(stream, "channel_layout"),
                    int.TryParse(GetString(stream, "sample_rate"), out var sampleRate) ? sampleRate : null,
                    GetString(tags, "language"),
                    GetInt(disposition, "default") == 1));
            }

            return new MediaMetadata(
                fullPath,
                GetString(format, "format_long_name") ?? GetString(format, "format_name") ?? "unknown",
                MediaTimestamp.FromSeconds(durationSeconds),
                MediaTimestamp.FromSeconds(startSeconds),
                video,
                audio,
                streams.Any(stream => GetString(stream, "codec_type") == "subtitle"),
                DateTimeOffset.UtcNow);
        }
        catch (MediaOperationException)
        {
            throw;
        }
        catch (Exception exception) when (exception is JsonException or InvalidOperationException or OverflowException)
        {
            throw new MediaOperationException(
                "source_unreadable",
                "動画情報の解析結果を読み取れませんでした。診断ログを確認してください。",
                result.StandardOutput + Environment.NewLine + result.StandardError,
                exception);
        }
    }

    public async Task<KeyframeIndex> InspectKeyframesAsync(MediaMetadata metadata, CancellationToken cancellationToken = default)
    {
        var result = await ProcessRunner.RunAsync(
            toolchain.FFprobePath,
            [
                "-v", "error",
                "-select_streams", "v:0",
                "-show_entries", "packet=pts_time,flags",
                "-show_packets",
                "-of", "json",
                metadata.SourcePath,
            ],
            cancellationToken: cancellationToken);

        if (result.ExitCode != 0)
        {
            throw new MediaOperationException("source_unreadable", "キーフレームを解析できませんでした。", result.StandardError);
        }

        try
        {
            using var document = JsonDocument.Parse(result.StandardOutput);
            var keyframes = new List<MediaTimestamp>();
            if (document.RootElement.TryGetProperty("packets", out var packets))
            {
                foreach (var packet in packets.EnumerateArray())
                {
                    if (!(GetString(packet, "flags") ?? string.Empty).Contains('K'))
                    {
                        continue;
                    }

                    if (ParseDouble(GetString(packet, "pts_time")) is { } raw)
                    {
                        keyframes.Add(MediaTimestamp.FromSeconds(Math.Max(0, raw - metadata.StartTimestamp.TotalSeconds)));
                    }
                }
            }

            return new KeyframeIndex(metadata.Duration, keyframes);
        }
        catch (Exception exception) when (exception is JsonException or InvalidOperationException or OverflowException)
        {
            throw new MediaOperationException("source_unreadable", "キーフレーム情報を読み取れませんでした。", result.StandardOutput, exception);
        }
    }

    private static string? GetString(JsonElement element, string name)
    {
        if (element.ValueKind != JsonValueKind.Object || !element.TryGetProperty(name, out var value))
        {
            return null;
        }

        return value.ValueKind == JsonValueKind.String ? value.GetString() : value.ToString();
    }

    private static int GetInt(JsonElement element, string name) =>
        int.TryParse(GetString(element, name), NumberStyles.Integer, CultureInfo.InvariantCulture, out var value) ? value : 0;

    private static double? ParseDouble(string? value) =>
        double.TryParse(value, NumberStyles.Float, CultureInfo.InvariantCulture, out var parsed) && double.IsFinite(parsed)
            ? parsed
            : null;
}
