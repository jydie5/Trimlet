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

let fractionalTimestamp = MediaTimestamp(value: 3_003, timescale: 1_001)
let normalizedTimestamp = MediaTimestamp(seconds: 3)
require(fractionalTimestamp == normalizedTimestamp, "equivalent rational timestamps should compare equally")
require(MediaTimestamp(seconds: 1.5) == MediaTimestamp(value: 3, timescale: 2), "seconds should normalize to an exact rational timestamp")

let intro = EditSegment(
    inPoint: MediaTimestamp(seconds: 1),
    outPoint: MediaTimestamp(seconds: 2.5)
)
let ending = EditSegment(
    inPoint: MediaTimestamp(seconds: 6),
    outPoint: MediaTimestamp(seconds: 8)
)
var editList = try EditList(segments: [ending, intro])
require(editList.segments.map(\.id) == [ending.id, intro.id], "edit-list order should remain explicit")
require(editList.totalDurationSeconds == 3.5, "edit list should sum retained durations")

do {
    try editList.append(EditSegment(
        inPoint: MediaTimestamp(seconds: 2),
        outPoint: MediaTimestamp(seconds: 3)
    ))
    require(false, "overlapping segments should be rejected")
} catch {
    require(error as? EditListError == .overlap, "overlap should report the shared edit-list error")
}

try editList.move(id: intro.id, by: -1)
require(editList.segments.map(\.id) == [intro.id, ending.id], "segments should be reorderable")
let updatedIntro = EditSegment(
    id: intro.id,
    inPoint: MediaTimestamp(seconds: 0.5),
    outPoint: MediaTimestamp(seconds: 2)
)
try editList.update(updatedIntro, sourceDuration: MediaTimestamp(seconds: 10))
require(editList.segments.first?.inPoint.seconds == 0.5, "a retained segment should be updateable")

let operationDirectory = URL(fileURLWithPath: "/tmp/trimlet-operation")
let incompleteOutput = URL(fileURLWithPath: "/tmp/trimlet-output.partial.mp4")
let multiAccuratePlan = try MultiRangeExportPlan(
    source: sourceWithSpaces,
    incompleteDestination: incompleteOutput,
    workingDirectory: operationDirectory,
    editList: editList,
    mode: .accurate,
    selectedAudioStreamIndex: 2,
    selectedAudioCodecName: "ac3",
    keyframeIndex: keyframes
)
require(multiAccuratePlan.stages.count == 3, "two segments should produce two encode stages and one concat stage")
require(multiAccuratePlan.stages[0].arguments.contains("0:2?"), "the selected absolute audio stream should be mapped")
require(multiAccuratePlan.stages[0].arguments.contains("h264_videotoolbox"), "multi-range Accurate should use VideoToolbox")
require(multiAccuratePlan.concatListContents.contains("segment-000.mp4"), "the concat list should preserve output order")

let multiFastPlan = try MultiRangeExportPlan(
    source: sourceWithSpaces,
    incompleteDestination: incompleteOutput,
    workingDirectory: operationDirectory,
    editList: editList,
    mode: .fast,
    selectedAudioStreamIndex: 2,
    selectedAudioCodecName: "ac3",
    keyframeIndex: KeyframeIndex(duration: 10, keyframes: [0, 2, 4, 6, 8, 10])
)
require(multiFastPlan.stages[0].arguments.contains("copy"), "multi-range Fast should stream-copy video")
require(multiFastPlan.stages[0].arguments.contains("aac"), "M2TS Fast should convert selected audio")
require(multiFastPlan.expectedDuration >= editList.totalDurationSeconds, "Fast candidates may expand retained ranges")

let movPCMPlan = try MultiRangeExportPlan(
    source: URL(fileURLWithPath: "/tmp/input.mov"),
    incompleteDestination: incompleteOutput,
    workingDirectory: operationDirectory,
    editList: editList,
    mode: .fast,
    selectedAudioStreamIndex: 1,
    selectedAudioCodecName: "pcm_s24le",
    keyframeIndex: KeyframeIndex(duration: 10, keyframes: [0, 2, 4, 6, 8, 10])
)
require(movPCMPlan.stages[0].arguments.contains("aac"), "MOV PCM audio should be converted for MP4 compatibility")

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
