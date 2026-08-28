import Foundation

public struct ExportStage: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case segment(index: Int)
        case concatenate
    }

    public let kind: Kind
    public let arguments: [String]
    public let expectedDuration: Double
    public let progressURL: URL
}

public struct MultiRangeExportPlan: Equatable, Sendable {
    public let mode: ExportMode
    public let stages: [ExportStage]
    public let segmentURLs: [URL]
    public let concatListURL: URL
    public let expectedDuration: Double
    public let effectiveRanges: [TrimRange]

    public init(
        source: URL,
        incompleteDestination: URL,
        workingDirectory: URL,
        editList: EditList,
        mode: ExportMode,
        selectedAudioStreamIndex: Int?,
        selectedAudioCodecName: String? = nil,
        keyframeIndex: KeyframeIndex?
    ) throws {
        guard !editList.segments.isEmpty else { throw MultiRangeExportPlanError.emptyEditList }

        let effectiveRanges: [TrimRange]
        switch mode {
        case .accurate:
            effectiveRanges = editList.segments.map(\.trimRange)
        case .fast:
            guard let keyframeIndex else { throw MultiRangeExportPlanError.keyframesUnavailable }
            effectiveRanges = try editList.segments.map { segment in
                guard let candidate = keyframeIndex.fastCandidate(for: segment.trimRange) else {
                    throw MultiRangeExportPlanError.noFastCandidate(segment.id)
                }
                return TrimRange(inPoint: candidate.start, outPoint: candidate.end)
            }
        }

        let sourceExtension = source.pathExtension.lowercased()
        var segmentURLs: [URL] = []
        var stages: [ExportStage] = []

        for (index, range) in effectiveRanges.enumerated() {
            guard let start = range.inPoint, let duration = range.duration else {
                throw MultiRangeExportPlanError.invalidRange
            }
            let output = workingDirectory
                .appendingPathComponent(String(format: "segment-%03d", index))
                .appendingPathExtension("mp4")
            let progress = workingDirectory
                .appendingPathComponent(String(format: "progress-%03d", index))
                .appendingPathExtension("txt")
            var arguments = [
                "-hide_banner", "-loglevel", "error", "-nostats", "-y",
                "-progress", progress.path, "-stats_period", "0.1"
            ]

            if mode == .fast {
                arguments += ["-ss", Self.time(start), "-i", source.path]
            } else {
                arguments += ["-i", source.path, "-ss", Self.time(start)]
            }
            arguments += ["-t", Self.time(duration), "-map", "0:v:0"]
            if let selectedAudioStreamIndex {
                arguments += ["-map", "0:\(selectedAudioStreamIndex)?"]
            } else {
                arguments += ["-an"]
            }

            switch mode {
            case .fast:
                arguments += ["-c:v", "copy"]
                if selectedAudioStreamIndex != nil {
                    if Self.fastAudioNeedsAACConversion(
                        sourceExtension: sourceExtension,
                        codecName: selectedAudioCodecName
                    ) {
                        arguments += ["-c:a", "aac", "-b:a", "256k"]
                    } else {
                        arguments += ["-c:a", "copy"]
                    }
                }
            case .accurate:
                arguments += ["-c:v", "h264_videotoolbox", "-b:v", "12M"]
                if selectedAudioStreamIndex != nil {
                    arguments += ["-c:a", "aac", "-b:a", "256k"]
                }
            }
            arguments += ["-avoid_negative_ts", "make_zero", "-movflags", "+faststart", output.path]
            segmentURLs.append(output)
            stages.append(ExportStage(
                kind: .segment(index: index),
                arguments: arguments,
                expectedDuration: duration,
                progressURL: progress
            ))
        }

        let concatListURL = workingDirectory.appendingPathComponent("segments.ffconcat")
        let concatProgressURL = workingDirectory.appendingPathComponent("progress-concat.txt")
        let expectedDuration = effectiveRanges.compactMap(\.duration).reduce(0, +)
        let concatArguments = [
            "-hide_banner", "-loglevel", "error", "-nostats", "-y",
            "-progress", concatProgressURL.path, "-stats_period", "0.1",
            "-f", "concat", "-safe", "0", "-i", concatListURL.path,
            "-c", "copy", "-movflags", "+faststart", incompleteDestination.path
        ]
        stages.append(ExportStage(
            kind: .concatenate,
            arguments: concatArguments,
            expectedDuration: expectedDuration,
            progressURL: concatProgressURL
        ))

        self.mode = mode
        self.stages = stages
        self.segmentURLs = segmentURLs
        self.concatListURL = concatListURL
        self.expectedDuration = expectedDuration
        self.effectiveRanges = effectiveRanges
    }

    public var concatListContents: String {
        segmentURLs.map { url in
            let escaped = url.path.replacingOccurrences(of: "'", with: "'\\''")
            return "file '\(escaped)'"
        }.joined(separator: "\n") + "\n"
    }

    private static func time(_ seconds: Double) -> String {
        String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), seconds)
    }

    private static func fastAudioNeedsAACConversion(
        sourceExtension: String,
        codecName: String?
    ) -> Bool {
        if sourceExtension == "m2ts" || sourceExtension == "mts" { return true }
        guard let codecName = codecName?.lowercased() else { return true }
        return !["aac", "mp3", "alac", "ac3", "eac3"].contains(codecName)
    }
}

public enum MultiRangeExportPlanError: LocalizedError, Equatable, Sendable {
    case emptyEditList
    case invalidRange
    case keyframesUnavailable
    case noFastCandidate(UUID)

    public var errorDescription: String? {
        switch self {
        case .emptyEditList:
            "書き出すクリップがありません。"
        case .invalidRange:
            "クリップのIN／OUTが正しくありません。"
        case .keyframesUnavailable:
            "高速モードに必要なキーフレーム解析が完了していません。"
        case .noFastCandidate:
            "高速モードで切り出せない区間があります。正確モードを使用してください。"
        }
    }
}
