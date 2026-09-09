// Run: swiftc -parse-as-library scripts/check-playback-compatibility.swift -o /tmp/trimlet-playback-check && /tmp/trimlet-playback-check

import CryptoKit
@preconcurrency import AVFoundation
import Darwin
import Foundation

struct PlaybackCompatibilityCheck {
    struct AssetInfo {
        let duration: Double
        let playable: Bool
        let videoTracks: Int
        let audioTracks: Int
    }

    struct CheckError: Error, CustomStringConvertible {
        let description: String
    }

    static func main() async {
        var report = ["Trimlet playback compatibility check", "date=\(ISO8601DateFormatter().string(from: Date()))"]
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent(
            "trimlet-playback-\(UUID().uuidString)", isDirectory: true
        )
        let reportURL = work.appendingPathComponent("report.txt")

        do {
            try fm.createDirectory(at: work, withIntermediateDirectories: true)
            report.append("workdir=\(work.path)")
            let ffmpeg = try findTool("ffmpeg")
            report.append("ffmpeg=\(ffmpeg.path)")

            let source = work.appendingPathComponent("vp9-opus-source.mp4")
            let preview = work.appendingPathComponent("h264-aac-preview.mp4")
            let exported = work.appendingPathComponent("h264-aac-export.mp4")
            try run(ffmpeg, arguments: [
                "-hide_banner", "-loglevel", "error", "-n",
                "-f", "lavfi", "-i", "testsrc2=size=640x360:rate=30",
                "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000",
                "-t", "3", "-map", "0:v:0", "-map", "1:a:0",
                "-c:v", "libvpx-vp9", "-b:v", "800k", "-pix_fmt", "yuv420p",
                "-c:a", "libopus", "-b:a", "96k", "-movflags", "+faststart", source.path
            ])
            let originalFingerprint = try fingerprint(source)
            let originalInfo = try await inspect(source)
            guard originalInfo.duration > 0, originalInfo.videoTracks > 0 else {
                throw CheckError(description: "合成素材に有効な時間または映像トラックがありません")
            }
            report.append(String(format: "source duration=%.3f video=%d audio=%d playable=%@",
                                 originalInfo.duration, originalInfo.videoTracks, originalInfo.audioTracks,
                                 String(originalInfo.playable)))
            if originalInfo.playable {
                report.append("VP9+Opus unsupported-path check: SKIPPED (this macOS can play the codec)")
            } else {
                report.append("VP9+Opus unsupported-path check: PASS (duration/tracks exist, AVFoundation isPlayable=false)")
            }

            try run(ffmpeg, arguments: [
                "-hide_banner", "-loglevel", "error", "-nostats", "-n",
                "-progress", work.appendingPathComponent("preview.progress").path,
                "-stats_period", "0.1", "-i", source.path,
                "-map", "0:v:0", "-map", "0:a:0?", "-vf", "scale='min(1280,iw)':-2",
                "-c:v", "h264_videotoolbox", "-b:v", "4M",
                "-c:a", "aac", "-b:a", "128k", "-movflags", "+faststart", preview.path
            ])
            let previewInfo = try await inspect(preview)
            try requirePlayable(previewInfo, label: "互換プレビュー")
            report.append(String(format: "preview duration=%.3f video=%d audio=%d playable=true PASS",
                                 previewInfo.duration, previewInfo.videoTracks, previewInfo.audioTracks))

            try run(ffmpeg, arguments: [
                "-hide_banner", "-loglevel", "error", "-nostats", "-n",
                "-progress", work.appendingPathComponent("export.progress").path,
                "-stats_period", "0.1", "-i", source.path, "-ss", "0.750000", "-t", "1.500000",
                "-map", "0:v:0", "-map", "0:a:0?", "-c:v", "h264_videotoolbox", "-b:v", "12M",
                "-c:a", "aac", "-b:a", "256k", "-avoid_negative_ts", "make_zero",
                "-movflags", "+faststart", exported.path
            ])
            let exportInfo = try await inspect(exported)
            try requirePlayable(exportInfo, label: "正確モード相当の書き出し")
            guard abs(exportInfo.duration - 1.5) <= 0.35 else {
                throw CheckError(description: String(format: "書き出し時間が想定外です: %.3f 秒", exportInfo.duration))
            }
            report.append(String(format: "export duration=%.3f video=%d audio=%d playable=true PASS",
                                 exportInfo.duration, exportInfo.videoTracks, exportInfo.audioTracks))

            guard try fingerprint(source) == originalFingerprint else {
                throw CheckError(description: "原本の内容が変化しました")
            }
            report.append("source unchanged: PASS")
            report.append("RESULT: PASS")
            try report.joined(separator: "\n").appending("\n").write(to: reportURL, atomically: true, encoding: .utf8)
            print(report.joined(separator: "\n"))
            print("report=\(reportURL.path)")
            exit(0)
        } catch {
            report.append("RESULT: FAIL — \(error)")
            try? fm.createDirectory(at: work, withIntermediateDirectories: true)
            try? report.joined(separator: "\n").appending("\n").write(to: reportURL, atomically: true, encoding: .utf8)
            fputs(report.joined(separator: "\n") + "\nreport=\(reportURL.path)\n", stderr)
            exit(1)
        }
    }

    static func findTool(_ name: String) throws -> URL {
        let candidates = ["/opt/homebrew/bin/\(name)", "/usr/local/bin/\(name)"]
        guard let path = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw CheckError(description: "\(name) が見つかりません（Homebrewの標準パスを確認してください）")
        }
        return URL(fileURLWithPath: path)
    }

    static func run(_ executable: URL, arguments: [String]) throws {
        let process = Process()
        let errorPipe = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errorPipe
        try process.run()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let details = String(data: errorData, encoding: .utf8) ?? ""
            throw CheckError(description: "\(executable.lastPathComponent) が失敗しました: \(details.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
    }

    static func inspect(_ url: URL) async throws -> AssetInfo {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let playable = try await asset.load(.isPlayable)
        let videos = try await asset.loadTracks(withMediaType: .video)
        let audios = try await asset.loadTracks(withMediaType: .audio)
        guard duration.seconds.isFinite, duration.seconds > 0 else {
            throw CheckError(description: "\(url.lastPathComponent) の時間を読み込めません")
        }
        return AssetInfo(duration: duration.seconds, playable: playable,
                         videoTracks: videos.count, audioTracks: audios.count)
    }

    static func requirePlayable(_ info: AssetInfo, label: String) throws {
        guard info.playable, info.videoTracks > 0, info.audioTracks > 0 else {
            throw CheckError(description: "\(label) が再生可能ではありません（video=\(info.videoTracks), audio=\(info.audioTracks), playable=\(info.playable)）")
        }
    }

    static func fingerprint(_ url: URL) throws -> String {
        let digest = SHA256.hash(data: try Data(contentsOf: url))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

@main
struct Main {
    static func main() async {
        await PlaybackCompatibilityCheck.main()
    }
}
