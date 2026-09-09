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
require(Set([fractionalTimestamp, normalizedTimestamp]).count == 1, "equivalent rational timestamps should hash equally")
require(MediaTimestamp(seconds: 1.5) == MediaTimestamp(value: 3, timescale: 2), "seconds should compare as an exact rational timestamp")
let largeTimestampLeft = MediaTimestamp(value: Int64.max - 1, timescale: Int32.max)
let largeTimestampRight = MediaTimestamp(value: Int64.max - 2, timescale: Int32.max - 1)
require(largeTimestampLeft < largeTimestampRight, "rational timestamp comparison should not overflow integer multiplication")

let intro = EditSegment(
    inPoint: MediaTimestamp(seconds: 1),
    outPoint: MediaTimestamp(seconds: 2.5),
    name: "Opening"
)
let ending = EditSegment(
    inPoint: MediaTimestamp(seconds: 6),
    outPoint: MediaTimestamp(seconds: 8),
    name: "Ending"
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
let middle = EditSegment(
    inPoint: MediaTimestamp(seconds: 3),
    outPoint: MediaTimestamp(seconds: 4)
)
var dragReorderList = try EditList(segments: [intro, middle, ending])
try dragReorderList.move(id: intro.id, to: 2)
require(dragReorderList.segments.map(\.id) == [middle.id, ending.id, intro.id], "a dragged segment should move to its target position")
try dragReorderList.move(id: intro.id, to: 0)
require(dragReorderList.segments.map(\.id) == [intro.id, middle.id, ending.id], "a dragged segment should move back to the first position")
require(dragReorderList.segments.first?.name == "Opening", "a clip's name should remain stable when reordered")
let updatedIntro = EditSegment(
    id: intro.id,
    inPoint: MediaTimestamp(seconds: 0.5),
    outPoint: MediaTimestamp(seconds: 2),
    name: intro.name
)
try editList.update(updatedIntro, sourceDuration: MediaTimestamp(seconds: 10))
require(editList.segments.first?.inPoint.seconds == 0.5, "a retained segment should be updateable")
require(editList.segments.first?.name == "Opening", "trimming a clip should preserve its name")
let encodedEditList = try JSONEncoder().encode(editList)
let decodedEditList = try JSONDecoder().decode(EditList.self, from: encodedEditList)
require(decodedEditList.segments.first?.name == "Opening", "a clip name should survive project-data serialization")

let projectSource = ProjectSourceReference(
    fileName: "日本語 source.m2ts",
    pathHint: "../Media/日本語 source.m2ts",
    sizeBytes: 123_456,
    modifiedAt: Date(timeIntervalSince1970: 1_777_777_777)
)
let project = TrimletProject(
    source: projectSource,
    editList: editList,
    settings: ProjectSettings(
        exportMode: .accurate,
        audio: ProjectAudioSelection(
            streamIndex: 2,
            codecName: "aac",
            language: "jpn",
            title: "Main"
        )
    )
)
let encodedProject = try TrimletProjectCodec.encode(project)
let decodedProject = try TrimletProjectCodec.decode(encodedProject)
require(decodedProject == project, "a project should survive canonical JSON round-trip")
require(decodedProject.editList.segments.map(\.name) == editList.segments.map(\.name), "project clips should preserve names and order")
require(decodedProject.settings.exportMode == .accurate, "project export mode should be restored")
require(decodedProject.settings.audio?.streamIndex == 2, "project audio selection should be restored")

let projectJSON = String(decoding: encodedProject, as: UTF8.self)
require(projectJSON.contains("\"in\""), "project timestamps should use the platform-neutral in key")
require(projectJSON.contains("\"out\""), "project timestamps should use the platform-neutral out key")
require(!projectJSON.contains("inPoint"), "project JSON should not expose Swift property names")

let repositoryRoot = (0..<5).reduce(URL(fileURLWithPath: #filePath)) { url, _ in
    url.deletingLastPathComponent()
}
let sharedProjectFixtureURL = repositoryRoot
    .appendingPathComponent("contracts/fixtures/project-cases.json")
let sharedProjectFixtureObject = try JSONSerialization.jsonObject(
    with: Data(contentsOf: sharedProjectFixtureURL)
) as! [String: Any]
let sharedProjectFixtureCases = sharedProjectFixtureObject["cases"] as! [[String: Any]]
for fixture in sharedProjectFixtureCases {
    let identifier = fixture["id"] as! String
    let expectedValidity = fixture["valid"] as! Bool
    let input = fixture["input"]!
    let inputData = try JSONSerialization.data(withJSONObject: input)
    let decodedFixture = try? TrimletProjectCodec.decode(inputData)
    let decodedSuccessfully = decodedFixture != nil
    require(
        decodedSuccessfully == expectedValidity,
        "shared project fixture \(identifier) should have validity \(expectedValidity)"
    )
    if let decodedFixture {
        let reencodedData = try TrimletProjectCodec.encode(decodedFixture)
        let reencodedObject = try JSONSerialization.jsonObject(with: reencodedData)
        let canonicalInput = try JSONSerialization.data(
            withJSONObject: input,
            options: [.sortedKeys]
        )
        let canonicalReencoded = try JSONSerialization.data(
            withJSONObject: reencodedObject,
            options: [.sortedKeys]
        )
        require(
            canonicalReencoded == canonicalInput,
            "shared project fixture \(identifier) should round-trip without changing its JSON values"
        )
    }
}

let oversizedProjectData = Data(
    repeating: 0,
    count: TrimletProjectCodec.maximumDocumentBytes + 1
)
do {
    _ = try TrimletProjectCodec.decode(oversizedProjectData)
    require(false, "an oversized project document should be rejected before decoding")
} catch {
    require(error as? TrimletProjectError == .documentTooLarge, "oversized project rejection should be explicit")
}

let oversizedOutputProject = TrimletProject(
    source: ProjectSourceReference(
        fileName: String(
            repeating: "x",
            count: TrimletProjectCodec.maximumDocumentBytes + 1
        ),
        pathHint: "source.mp4"
    ),
    editList: EditList()
)
do {
    _ = try TrimletProjectCodec.encode(oversizedOutputProject)
    require(false, "Trimlet should not write a project larger than its own read limit")
} catch {
    require(error as? TrimletProjectError == .documentTooLarge, "oversized project output rejection should be explicit")
}

let unsupportedProjectData = Data(projectJSON.replacingOccurrences(
    of: "\"schemaVersion\" : 1",
    with: "\"schemaVersion\" : 2"
).utf8)
do {
    _ = try TrimletProjectCodec.decode(unsupportedProjectData)
    require(false, "an unsupported project schema should be rejected")
} catch {
    require(error as? TrimletProjectError == .unsupportedSchema(2), "schema errors should be explicit")
}

let invalidTimestampData = Data("""
{"value":1,"timescale":0}
""".utf8)
do {
    _ = try JSONDecoder().decode(MediaTimestamp.self, from: invalidTimestampData)
    require(false, "a decoded zero timescale should be rejected")
} catch {
    require(error is DecodingError, "invalid timestamp data should report a decoding error")
}

let negativeTimestampData = Data("""
{"value":-1,"timescale":60000}
""".utf8)
do {
    _ = try JSONDecoder().decode(MediaTimestamp.self, from: negativeTimestampData)
    require(false, "a decoded negative timestamp should be rejected")
} catch {
    require(error is DecodingError, "negative timestamp data should report a decoding error")
}

let duplicateIdentifier = UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA")!
let duplicateProjectData = Data("""
{
  "schemaVersion": 1,
  "source": {"fileName":"source.mp4","pathHint":"source.mp4"},
  "editList": {"segments":[
    {"id":"\(duplicateIdentifier.uuidString)","in":{"value":0,"timescale":1},"out":{"value":1,"timescale":1}},
    {"id":"\(duplicateIdentifier.uuidString)","in":{"value":2,"timescale":1},"out":{"value":3,"timescale":1}}
  ]},
  "settings": {"exportMode":"fast"}
}
""".utf8)
do {
    _ = try TrimletProjectCodec.decode(duplicateProjectData)
    require(false, "duplicate project clip identifiers should be rejected")
} catch {
    require(error as? EditListError == .duplicateID, "duplicate project clips should report duplicateID")
}

let projectPathTestRoot = FileManager.default.temporaryDirectory
    .appendingPathComponent("trimlet-project-path-\(UUID().uuidString)", isDirectory: true)
let projectPathTestMedia = projectPathTestRoot
    .appendingPathComponent("Media 日本語", isDirectory: true)
    .appendingPathComponent("source clip.mp4")
let projectPathTestDocument = projectPathTestRoot
    .appendingPathComponent("Projects", isDirectory: true)
    .appendingPathComponent("edit.trimlet")
try FileManager.default.createDirectory(
    at: projectPathTestMedia.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try FileManager.default.createDirectory(
    at: projectPathTestDocument.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try Data("source".utf8).write(to: projectPathTestMedia)
defer { try? FileManager.default.removeItem(at: projectPathTestRoot) }
let capturedSource = try ProjectSourceReference.capture(
    sourceURL: projectPathTestMedia,
    relativeTo: projectPathTestDocument
)
require(capturedSource.pathHint == "../Media 日本語/source clip.mp4", "project source references should be relative, Unicode-safe, and portable")
require(capturedSource.candidateURL(relativeTo: projectPathTestDocument) == projectPathTestMedia, "a relative source reference should resolve beside the project")
require(capturedSource.matches(projectPathTestMedia), "an unchanged source should match its stored identity")
let diskProject = TrimletProject(
    source: capturedSource,
    editList: editList,
    settings: ProjectSettings(exportMode: .fast)
)
try TrimletProjectCodec.write(diskProject, to: projectPathTestDocument)
let readDiskProject = try TrimletProjectCodec.read(from: projectPathTestDocument)
require(
    readDiskProject == diskProject,
    "an atomically written project should read back unchanged"
)
try Data("changed source contents".utf8).write(to: projectPathTestMedia)
require(!capturedSource.matches(projectPathTestMedia), "a changed source should fail stored identity matching")

let absoluteSourceProjectData = Data("""
{
  "schemaVersion": 1,
  "source": {"fileName":"source.mp4","pathHint":"/Users/example/source.mp4"},
  "editList": {"segments":[]},
  "settings": {"exportMode":"fast"}
}
""".utf8)
do {
    _ = try TrimletProjectCodec.decode(absoluteSourceProjectData)
    require(false, "absolute project source paths should be rejected")
} catch {
    require(error as? TrimletProjectError == .invalidSourceReference, "absolute path rejection should be explicit")
}

let negativeSizeProject = TrimletProject(
    source: ProjectSourceReference(
        fileName: "source.mp4",
        pathHint: "source.mp4",
        sizeBytes: -1
    ),
    editList: EditList()
)
do {
    _ = try TrimletProjectCodec.encode(negativeSizeProject)
    require(false, "a negative source size should be rejected")
} catch {
    require(error as? TrimletProjectError == .invalidSourceReference, "negative source size rejection should be explicit")
}

let negativeAudioProject = TrimletProject(
    source: ProjectSourceReference(fileName: "source.mp4", pathHint: "source.mp4"),
    editList: EditList(),
    settings: ProjectSettings(
        exportMode: .fast,
        audio: ProjectAudioSelection(streamIndex: -1)
    )
)
do {
    _ = try TrimletProjectCodec.encode(negativeAudioProject)
    require(false, "a negative audio stream index should be rejected")
} catch {
    require(error as? TrimletProjectError == .invalidAudioSelection, "negative audio selection rejection should be explicit")
}

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

runTimelineViewportChecks()
runTimelineInteractionChecks()

print("TrimletCoreChecks: all checks passed")
