import Foundation

public struct ProjectSourceReference: Codable, Equatable, Sendable {
    public let fileName: String
    public let pathHint: String
    public let sizeBytes: Int64?
    public let modifiedAt: Date?

    public init(
        fileName: String,
        pathHint: String,
        sizeBytes: Int64? = nil,
        modifiedAt: Date? = nil
    ) {
        self.fileName = fileName
        self.pathHint = pathHint
        self.sizeBytes = sizeBytes
        self.modifiedAt = modifiedAt
    }

    public static func capture(sourceURL: URL, relativeTo projectURL: URL) throws -> Self {
        let source = sourceURL.standardizedFileURL
        let attributes = try FileManager.default.attributesOfItem(atPath: source.path)
        return Self(
            fileName: source.lastPathComponent,
            pathHint: relativePath(
                from: projectURL.deletingLastPathComponent().standardizedFileURL,
                to: source
            ),
            sizeBytes: (attributes[.size] as? NSNumber)?.int64Value,
            modifiedAt: (attributes[.modificationDate] as? Date).map {
                Date(timeIntervalSince1970: floor($0.timeIntervalSince1970))
            }
        )
    }

    public func candidateURL(relativeTo projectURL: URL) -> URL {
        URL(
            fileURLWithPath: pathHint,
            relativeTo: projectURL.deletingLastPathComponent()
        ).standardizedFileURL
    }

    public func matches(_ candidateURL: URL) -> Bool {
        let candidate = candidateURL.standardizedFileURL
        guard FileManager.default.fileExists(atPath: candidate.path),
              let attributes = try? FileManager.default.attributesOfItem(atPath: candidate.path) else {
            return false
        }
        if let sizeBytes,
           (attributes[.size] as? NSNumber)?.int64Value != sizeBytes {
            return false
        }
        if let modifiedAt,
           abs((attributes[.modificationDate] as? Date)?.timeIntervalSince(modifiedAt) ?? .infinity) > 1 {
            return false
        }
        return true
    }

    private static func relativePath(from baseDirectory: URL, to target: URL) -> String {
        let baseComponents = baseDirectory.pathComponents
        let targetComponents = target.pathComponents
        var commonCount = 0
        while commonCount < min(baseComponents.count, targetComponents.count),
              baseComponents[commonCount] == targetComponents[commonCount] {
            commonCount += 1
        }
        let parentComponents = Array(repeating: "..", count: baseComponents.count - commonCount)
        let childComponents = Array(targetComponents.dropFirst(commonCount))
        let components = parentComponents + childComponents
        return components.isEmpty ? target.lastPathComponent : components.joined(separator: "/")
    }
}

public struct ProjectAudioSelection: Codable, Equatable, Sendable {
    public let streamIndex: Int
    public let codecName: String?
    public let language: String?
    public let title: String?

    public init(
        streamIndex: Int,
        codecName: String? = nil,
        language: String? = nil,
        title: String? = nil
    ) {
        self.streamIndex = streamIndex
        self.codecName = codecName
        self.language = language
        self.title = title
    }
}

public struct ProjectSettings: Codable, Equatable, Sendable {
    public var exportMode: ExportMode
    public var audio: ProjectAudioSelection?

    public init(exportMode: ExportMode = .fast, audio: ProjectAudioSelection? = nil) {
        self.exportMode = exportMode
        self.audio = audio
    }
}

public struct TrimletProject: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public var source: ProjectSourceReference
    public var editList: EditList
    public var settings: ProjectSettings

    public init(
        source: ProjectSourceReference,
        editList: EditList,
        settings: ProjectSettings = ProjectSettings()
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.source = source
        self.editList = editList
        self.settings = settings
    }

    public func validate(sourceDuration: MediaTimestamp? = nil) throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw TrimletProjectError.unsupportedSchema(schemaVersion)
        }
        let hasDrivePrefix = source.pathHint.count >= 2
            && source.pathHint[source.pathHint.index(after: source.pathHint.startIndex)] == ":"
        guard !source.fileName.isEmpty,
              !source.pathHint.isEmpty,
              !source.pathHint.hasPrefix("/"),
              !hasDrivePrefix,
              !source.pathHint.contains("\\"),
              source.sizeBytes.map({ $0 >= 0 }) ?? true else {
            throw TrimletProjectError.invalidSourceReference
        }
        if let audio = settings.audio, audio.streamIndex < 0 {
            throw TrimletProjectError.invalidAudioSelection
        }
        try editList.validate(sourceDuration: sourceDuration)
    }
}

public enum TrimletProjectCodec {
    public static let maximumDocumentBytes = 8 * 1_024 * 1_024

    public static func encode(_ project: TrimletProject) throws -> Data {
        try project.validate()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(project)
        guard data.count <= maximumDocumentBytes else {
            throw TrimletProjectError.documentTooLarge
        }
        return data
    }

    public static func decode(_ data: Data) throws -> TrimletProject {
        guard data.count <= maximumDocumentBytes else {
            throw TrimletProjectError.documentTooLarge
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let project = try decoder.decode(TrimletProject.self, from: data)
        try rejectUnknownFields(in: data)
        try project.validate()
        return project
    }

    public static func read(from url: URL) throws -> TrimletProject {
        if let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber,
           fileSize.int64Value > Int64(maximumDocumentBytes) {
            throw TrimletProjectError.documentTooLarge
        }
        return try decode(Data(contentsOf: url))
    }

    public static func write(_ project: TrimletProject, to url: URL) throws {
        try encode(project).write(to: url, options: .atomic)
    }

    private static func rejectUnknownFields(in data: Data) throws {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        try rejectUnknownKeys(
            in: root,
            allowed: ["schemaVersion", "source", "editList", "settings"],
            path: "$"
        )

        if let source = root["source"] as? [String: Any] {
            try rejectUnknownKeys(
                in: source,
                allowed: ["fileName", "pathHint", "sizeBytes", "modifiedAt"],
                path: "$.source"
            )
        }
        if let editList = root["editList"] as? [String: Any] {
            try rejectUnknownKeys(in: editList, allowed: ["segments"], path: "$.editList")
            if let segments = editList["segments"] as? [[String: Any]] {
                for (index, segment) in segments.enumerated() {
                    let segmentPath = "$.editList.segments[\(index)]"
                    try rejectUnknownKeys(
                        in: segment,
                        allowed: ["id", "in", "out", "name"],
                        path: segmentPath
                    )
                    for boundary in ["in", "out"] {
                        if let timestamp = segment[boundary] as? [String: Any] {
                            try rejectUnknownKeys(
                                in: timestamp,
                                allowed: ["value", "timescale"],
                                path: "\(segmentPath).\(boundary)"
                            )
                        }
                    }
                }
            }
        }
        if let settings = root["settings"] as? [String: Any] {
            try rejectUnknownKeys(
                in: settings,
                allowed: ["exportMode", "audio"],
                path: "$.settings"
            )
            if let audio = settings["audio"] as? [String: Any] {
                try rejectUnknownKeys(
                    in: audio,
                    allowed: ["streamIndex", "codecName", "language", "title"],
                    path: "$.settings.audio"
                )
            }
        }
    }

    private static func rejectUnknownKeys(
        in object: [String: Any],
        allowed: Set<String>,
        path: String
    ) throws {
        if let unknown = object.keys.first(where: { !allowed.contains($0) }) {
            throw TrimletProjectError.unexpectedField("\(path).\(unknown)")
        }
    }
}

public enum TrimletProjectError: LocalizedError, Equatable, Sendable {
    case unsupportedSchema(Int)
    case invalidSourceReference
    case invalidAudioSelection
    case unexpectedField(String)
    case documentTooLarge

    public var errorDescription: String? {
        switch self {
        case let .unsupportedSchema(version):
            "このプロジェクト形式（バージョン\(version)）には対応していません。"
        case .invalidSourceReference:
            "プロジェクトの元動画情報が壊れています。"
        case .invalidAudioSelection:
            "プロジェクトの音声トラック情報が壊れています。"
        case let .unexpectedField(path):
            "プロジェクトに未対応の項目があります：\(path)"
        case .documentTooLarge:
            "プロジェクトファイルが大きすぎます（上限8 MB）。"
        }
    }
}
