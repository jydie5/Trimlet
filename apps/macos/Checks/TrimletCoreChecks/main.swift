import Foundation
import TrimletCore

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        FileHandle.standardError.write(Data("FAILED: \(message)\n".utf8))
        exit(1)
    }
}

let validRange = TrimRange(inPoint: 10.25, outPoint: 12.75)
require(validRange.isValid, "a forward range should be valid")
require(validRange.duration == 2.5, "valid range should report its duration")

require(!TrimRange(inPoint: 3, outPoint: 3).isValid, "an empty range should be invalid")
require(!TrimRange(inPoint: 5, outPoint: 2).isValid, "an inverted range should be invalid")
require(!TrimRange(inPoint: nil, outPoint: 2).isValid, "a partial range should be invalid")

var clampedRange = TrimRange(inPoint: -2, outPoint: 12)
clampedRange.clamp(to: 10)
require(clampedRange.inPoint == 0, "IN should clamp to zero")
require(clampedRange.outPoint == 10, "OUT should clamp to media duration")

require(
    TimecodeFormatter.string(seconds: 3_723.5, framesPerSecond: 30) == "01:02:03:15",
    "timecode should include hours and frames"
)
require(
    TimecodeFormatter.string(seconds: -1, framesPerSecond: 30) == "00:00:00:00",
    "negative time should be rejected"
)
require(
    TimecodeFormatter.string(seconds: .infinity, framesPerSecond: 30) == "00:00:00:00",
    "non-finite time should be rejected"
)

let sourceWithSpaces = URL(fileURLWithPath: "/tmp/日本語 test/input clip.m2ts")
let destinationWithSpaces = URL(fileURLWithPath: "/tmp/日本語 test/output clip.mp4")
let fastPlan = FFmpegExportPlan(
    source: sourceWithSpaces,
    destination: destinationWithSpaces,
    inPoint: 1.5,
    duration: 2.5,
    mode: .fast
)
require(
    fastPlan.arguments.firstIndex(of: "-ss")! < fastPlan.arguments.firstIndex(of: "-i")!,
    "Fast mode should seek before opening the input"
)
require(fastPlan.arguments.contains("-c:v"), "M2TS Fast mode should copy video explicitly")
require(fastPlan.arguments.contains("aac"), "M2TS Fast mode should convert audio to AAC")
require(
    fastPlan.arguments.contains(sourceWithSpaces.path),
    "source paths with spaces and Japanese text should remain one argument"
)

let accuratePlan = FFmpegExportPlan(
    source: sourceWithSpaces,
    destination: destinationWithSpaces,
    inPoint: 1.5,
    duration: 2.5,
    mode: .accurate
)
require(
    accuratePlan.arguments.firstIndex(of: "-i")! < accuratePlan.arguments.firstIndex(of: "-ss")!,
    "Accurate mode should decode before applying the exact output seek"
)
require(
    accuratePlan.arguments.contains("h264_videotoolbox"),
    "Accurate mode should use the Mac hardware H.264 encoder"
)

let progressURL = URL(fileURLWithPath: "/tmp/trimlet-progress.txt")
let progressPlan = FFmpegExportPlan(
    source: sourceWithSpaces,
    destination: destinationWithSpaces,
    inPoint: 1.5,
    duration: 2.5,
    mode: .accurate,
    progressURL: progressURL
)
require(progressPlan.arguments.contains(progressURL.path), "progress output path should be passed to FFmpeg")

let keyframes = KeyframeIndex(duration: 10, keyframes: [4, 0, 2, 2, -1, 12])
require(keyframes.keyframes == [0, 2, 4], "keyframes should be normalized, unique, and sorted")
let candidate = keyframes.fastCandidate(for: TrimRange(inPoint: 1.5, outPoint: 3.2))
require(candidate?.start == 0, "Fast candidate should begin at the preceding keyframe")
require(candidate?.end == 4, "Fast candidate should end at the following keyframe")

let repeatedProgress = """
out_time_us=1000000
progress=continue
out_time_us=2500000
progress=continue
"""
require(
    FFmpegProgress.elapsedSeconds(from: repeatedProgress) == 2.5,
    "progress parsing should use the latest repeated FFmpeg value"
)

print("TrimletCoreChecks: all checks passed")
