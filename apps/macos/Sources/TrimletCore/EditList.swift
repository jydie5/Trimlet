import Foundation

public struct EditSegment: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var inPoint: MediaTimestamp
    public var outPoint: MediaTimestamp
    public var clipNumber: Int?

    public init(
        id: UUID = UUID(),
        inPoint: MediaTimestamp,
        outPoint: MediaTimestamp,
        clipNumber: Int? = nil
    ) {
        self.id = id
        self.inPoint = inPoint
        self.outPoint = outPoint
        self.clipNumber = clipNumber
    }

    public init(id: UUID = UUID(), range: TrimRange, clipNumber: Int? = nil) throws {
        guard let start = range.inPoint,
              let end = range.outPoint,
              end > start else {
            throw EditListError.invalidRange
        }
        self.init(
            id: id,
            inPoint: MediaTimestamp(seconds: start),
            outPoint: MediaTimestamp(seconds: end),
            clipNumber: clipNumber
        )
    }

    public var isValid: Bool { outPoint > inPoint }
    public var durationSeconds: Double { max(0, outPoint.seconds - inPoint.seconds) }
    public var trimRange: TrimRange {
        TrimRange(inPoint: inPoint.seconds, outPoint: outPoint.seconds)
    }

    public func overlaps(_ other: EditSegment) -> Bool {
        inPoint < other.outPoint && other.inPoint < outPoint
    }
}

public struct EditList: Codable, Equatable, Sendable {
    public private(set) var segments: [EditSegment]

    public init() {
        segments = []
    }

    public init(segments: [EditSegment]) throws {
        self.segments = []
        for segment in segments {
            try append(segment)
        }
    }

    public var isEmpty: Bool { segments.isEmpty }
    public var totalDurationSeconds: Double {
        segments.reduce(0) { $0 + $1.durationSeconds }
    }

    public func segment(id: UUID?) -> EditSegment? {
        guard let id else { return nil }
        return segments.first { $0.id == id }
    }

    public mutating func append(_ segment: EditSegment, sourceDuration: MediaTimestamp? = nil) throws {
        try validate(segment, replacing: nil, sourceDuration: sourceDuration)
        segments.append(segment)
    }

    public mutating func update(_ segment: EditSegment, sourceDuration: MediaTimestamp? = nil) throws {
        guard let index = segments.firstIndex(where: { $0.id == segment.id }) else {
            throw EditListError.segmentNotFound
        }
        try validate(segment, replacing: segment.id, sourceDuration: sourceDuration)
        segments[index] = segment
    }

    @discardableResult
    public mutating func remove(id: UUID) throws -> EditSegment {
        guard let index = segments.firstIndex(where: { $0.id == id }) else {
            throw EditListError.segmentNotFound
        }
        return segments.remove(at: index)
    }

    public mutating func move(id: UUID, by offset: Int) throws {
        guard let from = segments.firstIndex(where: { $0.id == id }) else {
            throw EditListError.segmentNotFound
        }
        let destination = min(max(0, from + offset), segments.count - 1)
        guard destination != from else { return }
        let segment = segments.remove(at: from)
        segments.insert(segment, at: destination)
    }

    public mutating func move(id: UUID, to destinationIndex: Int) throws {
        guard let from = segments.firstIndex(where: { $0.id == id }) else {
            throw EditListError.segmentNotFound
        }
        let segment = segments.remove(at: from)
        let destination = min(max(0, destinationIndex), segments.count)
        segments.insert(segment, at: destination)
    }

    public func validate(sourceDuration: MediaTimestamp? = nil) throws {
        for segment in segments {
            try validate(segment, replacing: segment.id, sourceDuration: sourceDuration)
        }
    }

    private func validate(
        _ segment: EditSegment,
        replacing id: UUID?,
        sourceDuration: MediaTimestamp?
    ) throws {
        guard segment.isValid else { throw EditListError.invalidRange }
        if let sourceDuration, segment.outPoint > sourceDuration {
            throw EditListError.outsideSource
        }
        if segments.contains(where: { existing in
            existing.id != id && existing.overlaps(segment)
        }) {
            throw EditListError.overlap
        }
    }
}

public enum EditListError: LocalizedError, Equatable, Sendable {
    case invalidRange
    case outsideSource
    case overlap
    case segmentNotFound

    public var errorDescription: String? {
        switch self {
        case .invalidRange:
            "IN点をOUT点より前に設定してください。"
        case .outsideSource:
            "クリップが元動画の範囲外です。"
        case .overlap:
            "サブクリップが既存のクリップと重なっています。"
        case .segmentNotFound:
            "クリップが見つかりません。"
        }
    }
}
