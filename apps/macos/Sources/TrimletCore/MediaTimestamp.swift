import Foundation

public struct MediaTimestamp: Codable, Hashable, Sendable, Comparable {
    public static let editingTimescale: Int32 = 60_000

    public let value: Int64
    public let timescale: Int32

    public init(value: Int64, timescale: Int32) {
        precondition(value >= 0, "Media timestamps cannot be negative")
        precondition(timescale > 0, "Media timestamp timescale must be positive")
        self.value = value
        self.timescale = timescale
    }

    public init(seconds: Double, timescale: Int32 = MediaTimestamp.editingTimescale) {
        let safeTimescale = max(1, timescale)
        let safeSeconds = seconds.isFinite ? max(0, seconds) : 0
        self.init(
            value: Int64((safeSeconds * Double(safeTimescale)).rounded()),
            timescale: safeTimescale
        )
    }

    private enum CodingKeys: String, CodingKey {
        case value
        case timescale
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let value = try container.decode(Int64.self, forKey: .value)
        let timescale = try container.decode(Int32.self, forKey: .timescale)
        guard value >= 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .value,
                in: container,
                debugDescription: "Media timestamp value must not be negative."
            )
        }
        guard timescale > 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .timescale,
                in: container,
                debugDescription: "Media timestamp timescale must be positive."
            )
        }
        self.init(value: value, timescale: timescale)
    }

    public var seconds: Double {
        Double(value) / Double(timescale)
    }

    public static func == (lhs: MediaTimestamp, rhs: MediaTimestamp) -> Bool {
        lhs.reducedComponents == rhs.reducedComponents
    }

    public func hash(into hasher: inout Hasher) {
        let components = reducedComponents
        hasher.combine(components.value)
        hasher.combine(components.timescale)
    }

    public static func < (lhs: MediaTimestamp, rhs: MediaTimestamp) -> Bool {
        Decimal(lhs.value) * Decimal(rhs.timescale)
            < Decimal(rhs.value) * Decimal(lhs.timescale)
    }

    private var reducedComponents: (value: Int64, timescale: Int64) {
        let divisor = Self.greatestCommonDivisor(value, Int64(timescale))
        return (value / divisor, Int64(timescale) / divisor)
    }

    private static func greatestCommonDivisor(_ first: Int64, _ second: Int64) -> Int64 {
        var left = first
        var right = second
        while right != 0 {
            let remainder = left % right
            left = right
            right = remainder
        }
        return max(1, left)
    }
}
