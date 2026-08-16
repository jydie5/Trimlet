import Foundation

public struct FastCutCandidate: Equatable, Sendable {
    public let start: Double
    public let end: Double
    public let requestedStart: Double
    public let requestedEnd: Double

    public var startDelta: Double { start - requestedStart }
    public var endDelta: Double { end - requestedEnd }
}

public struct KeyframeIndex: Equatable, Sendable {
    public let duration: Double
    public let keyframes: [Double]

    public init(duration: Double, keyframes: [Double]) {
        self.duration = max(0, duration)
        self.keyframes = Array(Set(keyframes.filter { $0.isFinite && $0 >= 0 && $0 <= duration + 0.001 }))
            .sorted()
    }

    public func fastCandidate(for range: TrimRange) -> FastCutCandidate? {
        guard let requestedStart = range.inPoint,
              let requestedEnd = range.outPoint,
              requestedEnd > requestedStart,
              let start = keyframes.last(where: { $0 <= requestedStart + 0.000_001 }) else {
            return nil
        }

        let end = keyframes.first(where: { $0 >= requestedEnd - 0.000_001 }) ?? duration
        guard end > start else { return nil }
        return FastCutCandidate(
            start: start,
            end: min(end, duration),
            requestedStart: requestedStart,
            requestedEnd: requestedEnd
        )
    }
}
