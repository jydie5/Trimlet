import Foundation

public struct MediaTimestamp: Codable, Hashable, Sendable, Comparable {
    public static let editingTimescale: Int32 = 60_000

    public let value: Int64
    public let timescale: Int32

    public init(value: Int64, timescale: Int32) {
        precondition(value >= 0, "Media timestamps cannot be negative")
        precondition(timescale > 0, "Media timestamp timescale must be positive")
        let divisor = Self.greatestCommonDivisor(value, Int64(timescale))
        self.value = value / divisor
        self.timescale = Int32(Int64(timescale) / divisor)
    }

    public init(seconds: Double, timescale: Int32 = MediaTimestamp.editingTimescale) {
        let safeTimescale = max(1, timescale)
        let safeSeconds = seconds.isFinite ? max(0, seconds) : 0
        self.init(
            value: Int64((safeSeconds * Double(safeTimescale)).rounded()),
            timescale: safeTimescale
        )
    }

    public var seconds: Double {
        Double(value) / Double(timescale)
    }

    public static func < (lhs: MediaTimestamp, rhs: MediaTimestamp) -> Bool {
        Decimal(lhs.value) / Decimal(lhs.timescale) < Decimal(rhs.value) / Decimal(rhs.timescale)
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
