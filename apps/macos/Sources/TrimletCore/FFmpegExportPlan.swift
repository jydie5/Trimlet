import Foundation

public struct FFmpegExportPlan: Equatable, Sendable {
    public let arguments: [String]

    public init(
        source: URL,
        destination: URL,
        inPoint: Double,
        duration: Double,
        mode: ExportMode,
        progressURL: URL? = nil
    ) {
        var arguments = [
            "-hide_banner",
            "-loglevel", "error",
            "-nostats",
            "-y"
        ]

        if let progressURL {
            arguments += ["-progress", progressURL.path, "-stats_period", "0.1"]
        }

        switch mode {
        case .fast:
            arguments += [
                "-ss", Self.time(inPoint),
                "-i", source.path
            ]
        case .accurate:
            arguments += [
                "-i", source.path,
                "-ss", Self.time(inPoint)
            ]
        }

        arguments += [
            "-t", Self.time(duration),
            "-map", "0:v:0",
            "-map", "0:a:0?"
        ]

        switch mode {
        case .fast:
            let sourceExtension = source.pathExtension.lowercased()
            if sourceExtension == "m2ts" || sourceExtension == "mts" {
                arguments += [
                    "-c:v", "copy",
                    "-c:a", "aac",
                    "-b:a", "256k"
                ]
            } else {
                arguments += ["-c", "copy"]
            }
        case .accurate:
            arguments += [
                "-c:v", "h264_videotoolbox",
                "-b:v", "12M",
                "-c:a", "aac",
                "-b:a", "256k"
            ]
        }

        arguments += ["-movflags", "+faststart", destination.path]
        self.arguments = arguments
    }

    private static func time(_ seconds: Double) -> String {
        String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), seconds)
    }
}
