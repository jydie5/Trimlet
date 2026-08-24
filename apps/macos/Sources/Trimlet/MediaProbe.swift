import Foundation
import TrimletCore

enum MediaProbe {
    struct AudioStreamInfo: Identifiable, Hashable, Sendable {
        let index: Int
        let codecName: String
        let channels: Int?
        let language: String?
        let title: String?

        var id: Int { index }

        var displayName: String {
            var parts = ["音声 \(index)", codecName.uppercased()]
            if let channels { parts.append("\(channels)ch") }
            if let language, !language.isEmpty { parts.append(language) }
            if let title, !title.isEmpty, title != "SoundHandler" { parts.append(title) }
            return parts.joined(separator: " · ")
        }
    }

    struct OutputValidation: Sendable {
        let isValid: Bool
        let message: String
        let duration: Double?
    }

    private struct PacketDocument: Decodable {
        let packets: [Packet]?
        let streams: [Stream]?
    }

    private struct Packet: Decodable {
        let ptsTime: String?
        let flags: String?

        enum CodingKeys: String, CodingKey {
            case ptsTime = "pts_time"
            case flags
        }
    }

    private struct Stream: Decodable {
        let startTime: String?

        enum CodingKeys: String, CodingKey {
            case startTime = "start_time"
        }
    }

    private struct ValidationDocument: Decodable {
        let streams: [ValidationStream]?
        let format: ValidationFormat?
    }

    private struct ValidationStream: Decodable {
        let codecType: String?

        enum CodingKeys: String, CodingKey {
            case codecType = "codec_type"
        }
    }

    private struct ValidationFormat: Decodable {
        let duration: String?
    }

    private struct AudioDocument: Decodable {
        let streams: [AudioStream]?
    }

    private struct AudioStream: Decodable {
        let index: Int
        let codecName: String?
        let channels: Int?
        let tags: AudioTags?

        enum CodingKeys: String, CodingKey {
            case index
            case codecName = "codec_name"
            case channels
            case tags
        }
    }

    private struct AudioTags: Decodable {
        let language: String?
        let title: String?
        let handlerName: String?

        enum CodingKeys: String, CodingKey {
            case language
            case title
            case handlerName = "handler_name"
        }
    }

    static func audioStreams(at url: URL, ffprobeURL: URL) async -> [AudioStreamInfo] {
        await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = ffprobeURL
            process.arguments = [
                "-v", "error",
                "-select_streams", "a",
                "-show_entries", "stream=index,codec_name,channels:stream_tags=language,title,handler_name",
                "-of", "json",
                url.path
            ]
            let output = Pipe()
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else { return [] }
                let data = output.fileHandleForReading.readDataToEndOfFile()
                let document = try JSONDecoder().decode(AudioDocument.self, from: data)
                return (document.streams ?? []).map { stream in
                    AudioStreamInfo(
                        index: stream.index,
                        codecName: stream.codecName ?? "unknown",
                        channels: stream.channels,
                        language: stream.tags?.language,
                        title: stream.tags?.title ?? stream.tags?.handlerName
                    )
                }
            } catch {
                return []
            }
        }.value
    }

    static func keyframeIndex(from data: Data, duration: Double) throws -> KeyframeIndex {
        let document = try JSONDecoder().decode(PacketDocument.self, from: data)
        let start = document.streams?.first?.startTime.flatMap(Double.init) ?? 0
        let times = (document.packets ?? []).compactMap { packet -> Double? in
            guard packet.flags?.contains("K") == true,
                  let raw = packet.ptsTime.flatMap(Double.init) else { return nil }
            return max(0, raw - start)
        }
        return KeyframeIndex(duration: duration, keyframes: times)
    }

    static func validateOutput(
        at url: URL,
        expectedDuration: Double,
        expectsAudio: Bool,
        durationTolerance: Double = 1,
        ffprobeURL: URL
    ) -> OutputValidation {
        let process = Process()
        process.executableURL = ffprobeURL
        process.arguments = [
            "-v", "error",
            "-show_entries", "stream=codec_type",
            "-show_entries", "format=duration",
            "-of", "json",
            url.path
        ]
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors

        do {
            try process.run()
            process.waitUntilExit()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            guard process.terminationStatus == 0 else {
                return OutputValidation(isValid: false, message: "出力ファイルを解析できません。", duration: nil)
            }
            let document = try JSONDecoder().decode(ValidationDocument.self, from: data)
            guard document.streams?.contains(where: { $0.codecType == "video" }) == true else {
                return OutputValidation(isValid: false, message: "映像ストリームがありません。正確モードを試してください。", duration: nil)
            }
            if expectsAudio,
               document.streams?.contains(where: { $0.codecType == "audio" }) != true {
                return OutputValidation(isValid: false, message: "原本にある音声が出力されていません。", duration: nil)
            }
            guard let durationText = document.format?.duration,
                  let duration = Double(durationText), duration.isFinite, duration > 0.001 else {
                return OutputValidation(isValid: false, message: "出力時間を確認できません。", duration: nil)
            }
            let allowedDifference = max(0.05, durationTolerance)
            guard abs(duration - expectedDuration) <= allowedDifference else {
                return OutputValidation(isValid: false, message: "出力時間が指定範囲から大きく外れています。", duration: duration)
            }
            return OutputValidation(isValid: true, message: "映像と出力時間を確認しました。", duration: duration)
        } catch {
            return OutputValidation(isValid: false, message: "出力検証に失敗しました：\(error.localizedDescription)", duration: nil)
        }
    }
}
