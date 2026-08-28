import Foundation
import TrimletCore

private enum CheckError: LocalizedError {
    case missingTool(String)
    case commandFailed(String)
    case invalidOutput(String)

    var errorDescription: String? {
        switch self {
        case .missingTool(let tool): "Required tool was not found: \(tool)"
        case .commandFailed(let detail): "Command failed: \(detail)"
        case .invalidOutput(let detail): "Output validation failed: \(detail)"
        }
    }
}

private struct ProbeDocument: Decodable {
    struct Stream: Decodable {
        let codecType: String?

        enum CodingKeys: String, CodingKey {
            case codecType = "codec_type"
        }
    }
    struct Format: Decodable { let duration: String? }
    let streams: [Stream]?
    let format: Format?

    enum CodingKeys: String, CodingKey {
        case streams
        case format
    }
}

private enum ExpectedColor: String {
    case red
    case green
    case blue
}

private func executable(named name: String) throws -> URL {
    let candidates = [
        "/opt/homebrew/bin/\(name)",
        "/usr/local/bin/\(name)",
        "/usr/bin/\(name)"
    ]
    guard let path = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
        throw CheckError.missingTool(name)
    }
    return URL(fileURLWithPath: path)
}

@discardableResult
private func run(_ executable: URL, _ arguments: [String]) throws -> Data {
    let process = Process()
    process.executableURL = executable
    process.arguments = arguments
    let output = Pipe()
    let errors = Pipe()
    process.standardOutput = output
    process.standardError = errors
    try process.run()
    process.waitUntilExit()
    let outputData = output.fileHandleForReading.readDataToEndOfFile()
    let errorData = errors.fileHandleForReading.readDataToEndOfFile()
    guard process.terminationStatus == 0 else {
        let detail = String(data: errorData, encoding: .utf8)?
            .split(separator: "\n").last.map(String.init) ?? "exit \(process.terminationStatus)"
        throw CheckError.commandFailed(detail)
    }
    return outputData
}

private func validate(
    _ output: URL,
    expectedDuration: Double,
    tolerance: Double,
    ffprobe: URL
) throws {
    let data = try run(ffprobe, [
        "-v", "error",
        "-show_entries", "stream=codec_type",
        "-show_entries", "format=duration",
        "-of", "json",
        output.path
    ])
    let document = try JSONDecoder().decode(ProbeDocument.self, from: data)
    let streamTypes = (document.streams ?? []).compactMap(\.codecType)
    guard streamTypes.contains("video"), streamTypes.contains("audio") else {
        throw CheckError.invalidOutput("\(output.lastPathComponent): streams=\(streamTypes)")
    }
    guard let durationText = document.format?.duration,
          let duration = Double(durationText),
          abs(duration - expectedDuration) <= tolerance else {
        throw CheckError.invalidOutput(
            "\(output.lastPathComponent): expected \(expectedDuration) ± \(tolerance), actual \(document.format?.duration ?? "missing")"
        )
    }
}

private func dominantColor(
    at seconds: Double,
    in output: URL,
    ffmpeg: URL
) throws -> ExpectedColor {
    let pixel = try run(ffmpeg, [
        "-hide_banner", "-loglevel", "error",
        "-ss", String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), seconds),
        "-i", output.path,
        "-frames:v", "1",
        "-vf", "scale=1:1,format=rgb24",
        "-f", "rawvideo", "pipe:1"
    ])
    guard pixel.count >= 3 else {
        throw CheckError.invalidOutput("could not sample color at \(seconds) seconds")
    }
    let channels = [
        (ExpectedColor.red, Int(pixel[pixel.startIndex])),
        (ExpectedColor.green, Int(pixel[pixel.startIndex + 1])),
        (ExpectedColor.blue, Int(pixel[pixel.startIndex + 2]))
    ]
    guard let dominant = channels.max(by: { $0.1 < $1.1 }), dominant.1 >= 60 else {
        throw CheckError.invalidOutput("ambiguous color sample at \(seconds) seconds")
    }
    return dominant.0
}

private func validateColorOrder(
    _ output: URL,
    samples: [(Double, ExpectedColor)],
    ffmpeg: URL
) throws {
    for (seconds, expected) in samples {
        let actual = try dominantColor(at: seconds, in: output, ffmpeg: ffmpeg)
        guard actual == expected else {
            throw CheckError.invalidOutput(
                "\(output.lastPathComponent) at \(seconds) seconds: expected \(expected.rawValue), actual \(actual.rawValue)"
            )
        }
    }
}

private func validateSelectedFrequency(
    _ output: URL,
    expectedFrequency: Double,
    ffmpeg: URL
) throws {
    let sampleRate = 48_000.0
    let duration = 0.5
    let pcm = try run(ffmpeg, [
        "-hide_banner", "-loglevel", "error",
        "-ss", "0.1", "-i", output.path,
        "-t", String(duration),
        "-map", "0:a:0", "-vn", "-ac", "1", "-ar", String(Int(sampleRate)),
        "-f", "s16le", "pipe:1"
    ])
    guard pcm.count >= 4 else {
        throw CheckError.invalidOutput("could not decode selected audio")
    }
    var crossings = 0
    var previous = Int16(0)
    var hasPrevious = false
    var index = 0
    while index + 1 < pcm.count {
        let raw = UInt16(pcm[index]) | (UInt16(pcm[index + 1]) << 8)
        let sample = Int16(bitPattern: raw)
        if hasPrevious, (previous < 0 && sample >= 0) || (previous >= 0 && sample < 0) {
            crossings += 1
        }
        previous = sample
        hasPrevious = true
        index += 2
    }
    let measured = Double(crossings) / (2 * duration)
    guard abs(measured - expectedFrequency) <= 30 else {
        throw CheckError.invalidOutput(
            String(format: "expected %.0f Hz selected audio, measured %.1f Hz", expectedFrequency, measured)
        )
    }
}

private func execute(
    plan: MultiRangeExportPlan,
    ffmpeg: URL,
    finalOutput: URL,
    ffprobe: URL,
    tolerance: Double
) throws {
    try plan.concatListContents.write(to: plan.concatListURL, atomically: true, encoding: .utf8)
    for stage in plan.stages {
        try run(ffmpeg, stage.arguments)
    }
    try validate(finalOutput, expectedDuration: plan.expectedDuration, tolerance: tolerance, ffprobe: ffprobe)
}

do {
    let ffmpeg = try executable(named: "ffmpeg")
    let ffprobe = try executable(named: "ffprobe")
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("trimlet-multirange-check-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let source = root.appendingPathComponent("source 日本語 test.mp4")
    try run(ffmpeg, [
        "-hide_banner", "-loglevel", "error", "-y",
        "-f", "lavfi", "-i", "color=c=black:size=640x360:rate=30",
        "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000",
        "-f", "lavfi", "-i", "sine=frequency=880:sample_rate=48000",
        "-t", "12",
        "-map", "0:v:0", "-map", "1:a:0", "-map", "2:a:0",
        "-vf", "drawbox=x=0:y=0:w=iw:h=ih:color=red:t=fill:enable='lt(t,4)',drawbox=x=0:y=0:w=iw:h=ih:color=blue:t=fill:enable='between(t,4,8)',drawbox=x=0:y=0:w=iw:h=ih:color=green:t=fill:enable='gte(t,8)'",
        "-c:v", "libx264", "-pix_fmt", "yuv420p",
        "-g", "60", "-keyint_min", "60", "-sc_threshold", "0",
        "-c:a", "aac", "-b:a", "128k",
        "-movflags", "+faststart",
        source.path
    ])

    let late = EditSegment(
        inPoint: MediaTimestamp(seconds: 6.25),
        outPoint: MediaTimestamp(seconds: 7.25)
    )
    let intro = EditSegment(
        inPoint: MediaTimestamp(seconds: 1.25),
        outPoint: MediaTimestamp(seconds: 2.75)
    )
    let ending = EditSegment(
        inPoint: MediaTimestamp(seconds: 9.1),
        outPoint: MediaTimestamp(seconds: 10.4)
    )
    let editList = try EditList(segments: [late, intro, ending])
    let keyframes = KeyframeIndex(duration: 12, keyframes: stride(from: 0.0, through: 12, by: 2).map { $0 })

    let accurateDirectory = root.appendingPathComponent("accurate", isDirectory: true)
    try FileManager.default.createDirectory(at: accurateDirectory, withIntermediateDirectories: true)
    let accurateOutput = root.appendingPathComponent("accurate combined.mp4")
    let accuratePlan = try MultiRangeExportPlan(
        source: source,
        incompleteDestination: accurateOutput,
        workingDirectory: accurateDirectory,
        editList: editList,
        mode: .accurate,
        selectedAudioStreamIndex: 2,
        selectedAudioCodecName: "aac",
        keyframeIndex: keyframes
    )
    try execute(
        plan: accuratePlan,
        ffmpeg: ffmpeg,
        finalOutput: accurateOutput,
        ffprobe: ffprobe,
        tolerance: 0.25
    )
    try validateColorOrder(
        accurateOutput,
        samples: [(0.4, .blue), (1.5, .red), (3.0, .green)],
        ffmpeg: ffmpeg
    )
    try validateSelectedFrequency(accurateOutput, expectedFrequency: 880, ffmpeg: ffmpeg)

    let fastDirectory = root.appendingPathComponent("fast", isDirectory: true)
    try FileManager.default.createDirectory(at: fastDirectory, withIntermediateDirectories: true)
    let fastOutput = root.appendingPathComponent("fast combined.mp4")
    let fastPlan = try MultiRangeExportPlan(
        source: source,
        incompleteDestination: fastOutput,
        workingDirectory: fastDirectory,
        editList: editList,
        mode: .fast,
        selectedAudioStreamIndex: 2,
        selectedAudioCodecName: "aac",
        keyframeIndex: keyframes
    )
    try execute(
        plan: fastPlan,
        ffmpeg: ffmpeg,
        finalOutput: fastOutput,
        ffprobe: ffprobe,
        tolerance: 1
    )
    try validateColorOrder(
        fastOutput,
        samples: [(0.5, .blue), (3.0, .red), (8.0, .green)],
        ffmpeg: ffmpeg
    )
    try validateSelectedFrequency(fastOutput, expectedFrequency: 880, ffmpeg: ffmpeg)

    print(String(format: "TrimletIntegrationChecks: Accurate %.3f s, Fast %.3f s passed", accuratePlan.expectedDuration, fastPlan.expectedDuration))
} catch {
    FileHandle.standardError.write(Data("FAILED: \(error.localizedDescription)\n".utf8))
    exit(1)
}
