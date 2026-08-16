import Foundation
import TrimletCore

enum MediaProbe {
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
            let maximumReasonableDuration = max(expectedDuration * 2, expectedDuration + 5)
            guard duration <= maximumReasonableDuration else {
                return OutputValidation(isValid: false, message: "出力時間が指定範囲から大きく外れています。", duration: duration)
            }
            return OutputValidation(isValid: true, message: "映像と出力時間を確認しました。", duration: duration)
        } catch {
            return OutputValidation(isValid: false, message: "出力検証に失敗しました：\(error.localizedDescription)", duration: nil)
        }
    }
}
