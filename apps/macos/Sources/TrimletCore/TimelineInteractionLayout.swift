import Foundation

/// Geometry and hit-testing rules for the source timeline.
///
/// The timeline reserves a small horizontal gutter on either side of its
/// time-mapped content.  Those gutters give the outward IN/OUT grips room at
/// the media edges without changing the source-time mapping.
public struct TimelineInteractionLayout: Equatable, Sendable {
    public static let height = 84.0
    public static let gutter = 24.0
    public static let gripWidth = 24.0

    /// The finite, non-negative width used by this layout.
    public let width: Double

    /// The source-time viewport represented by the layout.
    public let viewport: TimelineViewport

    public init(width: Double, viewport: TimelineViewport) {
        self.width = Self.safeWidth(width)
        self.viewport = viewport
    }

    /// The width available for source-time mapping, excluding both gutters.
    public var contentWidth: Double {
        max(0, width - (Self.gutter * 2))
    }

    /// The x-coordinate where the time-mapped content begins.
    public var inset: Double {
        Self.gutter
    }

    /// Maps an absolute source timestamp to the layout's x-coordinate.
    ///
    /// Timestamps outside the visible viewport are clamped to its nearest
    /// content edge.  Non-finite timestamps safely resolve to the left edge.
    public func x(for time: Double) -> Double {
        guard contentWidth > 0 else { return inset }
        guard time.isFinite else {
            return time == .infinity ? inset + contentWidth : inset
        }
        return inset + (contentWidth * viewport.fraction(for: time))
    }

    /// Maps an x-coordinate to an absolute source timestamp.
    ///
    /// The gutters clamp to the corresponding viewport edge; they do not
    /// represent extra media time.  Non-finite x-coordinates are handled as
    /// the nearest finite edge (NaN uses the left edge).
    public func time(at x: Double) -> Double {
        guard contentWidth > 0 else { return viewport.start }
        guard x.isFinite else {
            return x == .infinity ? viewport.end : viewport.start
        }
        let fraction = (x - inset) / contentWidth
        return viewport.time(at: fraction)
    }

    public enum Target: Equatable, Sendable {
        case seek
        case start
        case end
    }

    /// Determines the role of a pointer-down in the timeline.
    ///
    /// Boundary grips are only active in the lower range lane (`40..<72`).
    /// Their outward intervals are half-open and therefore remain exclusive,
    /// including when IN and OUT are at the same source timestamp.  An
    /// endpoint outside the current viewport is not visible and cannot be
    /// targeted; all other locations seek the playhead.
    public func target(
        x: Double,
        y: Double,
        inPoint: Double?,
        outPoint: Double?
    ) -> Target {
        guard width > 0,
              contentWidth > 0,
              viewport.span > 0,
              y.isFinite,
              y >= 40,
              y < 72,
              x.isFinite else {
            return .seek
        }

        if let inPoint, isVisible(inPoint) {
            let inX = self.x(for: inPoint)
            if x >= inX - Self.gripWidth, x < inX {
                return .start
            }
        }

        if let outPoint, isVisible(outPoint) {
            let outX = self.x(for: outPoint)
            if x >= outX, x < outX + Self.gripWidth {
                return .end
            }
        }

        return .seek
    }

    /// Translates a source timestamp by a horizontal pointer delta.
    ///
    /// The delta is measured against the current viewport scale, but the
    /// resulting timestamp is clamped to the complete source duration.  This
    /// is intentionally based on the boundary's initial timestamp rather than
    /// the pointer's absolute x-coordinate, so grabbing padded grip space does
    /// not make a boundary jump.
    public func translatedTime(from initial: Double, deltaX: Double) -> Double {
        let safeInitial = Self.clampToDuration(initial, duration: viewport.duration)

        guard viewport.duration > 0,
              contentWidth > 0,
              deltaX.isFinite,
              viewport.span.isFinite else {
            if deltaX == .infinity { return viewport.duration }
            if deltaX == -.infinity { return 0 }
            return safeInitial
        }

        let fraction = deltaX / contentWidth
        guard fraction.isFinite else {
            return deltaX.sign == .minus ? 0 : viewport.duration
        }

        let deltaSeconds = fraction * viewport.span
        guard deltaSeconds.isFinite else {
            return deltaSeconds.sign == .minus ? 0 : viewport.duration
        }

        // Compare against the duration before adding to avoid a finite but
        // very large delta overflowing and wrapping into an invalid value.
        if deltaSeconds > 0 {
            let remaining = viewport.duration - safeInitial
            return deltaSeconds >= remaining
                ? viewport.duration
                : safeInitial + deltaSeconds
        }
        if deltaSeconds < 0 {
            return safeInitial + deltaSeconds <= 0 ? 0 : safeInitial + deltaSeconds
        }
        return safeInitial
    }

    private func isVisible(_ time: Double) -> Bool {
        time.isFinite && time >= viewport.start && time <= viewport.end
    }

    private static func safeWidth(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return max(0, value)
    }

    private static func clampToDuration(_ value: Double, duration: Double) -> Double {
        guard duration.isFinite, duration > 0 else { return 0 }
        if value == .infinity { return duration }
        if !value.isFinite { return 0 }
        return min(max(value, 0), duration)
    }
}
