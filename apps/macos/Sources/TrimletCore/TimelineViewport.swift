import Foundation

/// A finite, clamped view into a media timeline.
///
/// `start`, `span`, and `end` are expressed in seconds in the source media
/// timeline. The viewport always satisfies `0 <= start <= end <= duration`.
/// A zero-duration media item has a zero-width viewport at time zero.
public struct TimelineViewport: Equatable, Sendable {
    public let duration: Double
    public let start: Double
    public let span: Double

    public var end: Double {
        // The initializer establishes this sum as finite and bounded. Keep
        // the calculation in one place so callers never have to reconstruct
        // the viewport's right edge themselves.
        min(duration, start + span)
    }

    public init(duration: Double, start: Double = 0, span: Double? = nil) {
        let safeDuration = Self.nonNegativeFinite(duration)
        guard safeDuration > 0 else {
            self.duration = 0
            self.start = 0
            self.span = 0
            return
        }

        let requestedSpan = span.map(Self.nonNegativeFinite) ?? safeDuration
        let safeSpan = min(
            safeDuration,
            requestedSpan > 0 ? requestedSpan : safeDuration
        )
        let maxStart = safeDuration - safeSpan
        let safeStart = Self.clamp(Self.finiteOrZero(start), lower: 0, upper: maxStart)

        self.duration = safeDuration
        self.start = safeStart
        self.span = safeSpan
    }

    /// Creates a viewport showing the complete media item.
    public static func full(duration: Double) -> Self {
        Self(duration: duration, start: 0, span: nil)
    }

    /// Maps an absolute source time into the visible fraction `[0, 1]`.
    /// Times outside the viewport are clamped to the nearest edge.
    public func fraction(for time: Double) -> Double {
        guard span > 0, time.isFinite else { return 0 }
        return Self.clamp((time - start) / span, lower: 0, upper: 1)
    }

    /// Maps a visible fraction to an absolute source time.
    /// Fractions outside `[0, 1]` and non-finite values are clamped safely.
    public func time(at fraction: Double) -> Double {
        guard span > 0 else { return start }
        let safeFraction = Self.clamp(Self.finiteOrZero(fraction), lower: 0, upper: 1)
        return start + (span * safeFraction)
    }

    /// Zooms the viewport around a normalized visible anchor.
    ///
    /// A factor greater than one zooms in. The anchor is a visible fraction
    /// (`0` is the left edge and `1` is the right edge), so the source time
    /// under that point remains stable whenever the bounds permit it.
    public func zoomed(
        by factor: Double,
        anchor: Double = 0.5,
        minimumSpan: Double = 0.1
    ) -> Self {
        guard duration > 0, factor.isFinite, factor > 0 else { return self }

        let safeAnchor = Self.clamp(Self.finiteOrZero(anchor), lower: 0, upper: 1)
        let safeMinimumSpan = Self.minimumSpan(
            minimumSpan,
            duration: duration
        )
        let requestedSpan = span / factor
        let nextSpan = Self.clamp(
            requestedSpan.isFinite ? requestedSpan : duration,
            lower: safeMinimumSpan,
            upper: duration
        )
        let anchorTime = time(at: safeAnchor)
        let nextStart = anchorTime - (nextSpan * safeAnchor)
        return Self(duration: duration, start: nextStart, span: nextSpan)
    }

    /// Zooms around an absolute source time instead of a visible fraction.
    /// The time is clamped to the current viewport before applying the zoom.
    public func zoomed(
        by factor: Double,
        anchorTime: Double,
        minimumSpan: Double = 0.1
    ) -> Self {
        zoomed(
            by: factor,
            anchor: fraction(for: anchorTime),
            minimumSpan: minimumSpan
        )
    }

    /// Moves the viewport by seconds and clamps it to the media bounds.
    /// Positive deltas move toward the end of the source media.
    public func panned(by delta: Double) -> Self {
        guard duration > 0, delta.isFinite else { return self }
        let maximumStart = duration - span
        let nextStart: Double
        if delta > 0 {
            // Compare before adding so a very large finite delta cannot
            // overflow to infinity and wrap back to the left edge.
            let remaining = maximumStart - start
            nextStart = delta >= remaining ? maximumStart : start + delta
        } else if delta < 0 {
            nextStart = start + delta <= 0 ? 0 : start + delta
        } else {
            nextStart = start
        }
        return Self(duration: duration, start: nextStart, span: span)
    }

    /// Moves the viewport only as much as needed to reveal a source time.
    /// If the time is already visible, this returns the current viewport.
    public func revealing(_ time: Double) -> Self {
        guard duration > 0, time.isFinite else { return self }
        let nextStart: Double
        if time < start {
            nextStart = time
        } else if time > end {
            nextStart = time - span
        } else {
            return self
        }
        return Self(duration: duration, start: nextStart, span: span)
    }

    /// Snaps a finite source time to the nearest nominal frame boundary.
    /// The result is clamped to the media duration.
    public func snapping(_ time: Double, toFrameRate frameRate: Double) -> Double {
        guard duration > 0, time.isFinite, frameRate.isFinite, frameRate > 0 else {
            return time.isFinite ? Self.clamp(time, lower: 0, upper: duration) : 0
        }
        let frame = (Self.clamp(time, lower: 0, upper: duration) * frameRate).rounded()
        let snapped = frame / frameRate
        return Self.clamp(snapped, lower: 0, upper: duration)
    }

    private static func nonNegativeFinite(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return max(0, value)
    }

    private static func finiteOrZero(_ value: Double) -> Double {
        value.isFinite ? value : 0
    }

    private static func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), upper)
    }

    private static func minimumSpan(_ requested: Double, duration: Double) -> Double {
        guard requested.isFinite, requested > 0 else {
            return min(duration, 0.1)
        }
        return min(duration, requested)
    }
}

public extension TrimRange {
    /// Identifies the endpoint that should be moved in a draft range.
    enum Boundary: Sendable {
        case start
        case end
    }

    /// Returns a copy with one draft endpoint moved to a nominal frame boundary.
    ///
    /// The opposite endpoint is kept in place. If the requested endpoint would
    /// cross it, the requested endpoint is clamped instead. A one-frame range
    /// is preserved whenever the source duration makes that possible; for a
    /// shorter source the closest valid boundary is used. `frameRate` is a
    /// nominal rate and is intentionally not a VFR frame-index substitute.
    ///
    /// A missing selected endpoint is not invented. In particular, moving OUT
    /// requires both an existing IN and OUT. An invalid source duration leaves
    /// the range unchanged.
    func movingBoundary(
        _ boundary: Boundary,
        to requestedSeconds: Double,
        duration: Double,
        frameRate: Double
    ) -> Self {
        guard duration.isFinite, duration >= 0 else { return self }

        switch boundary {
        case .start:
            guard inPoint != nil else { return self }
        case .end:
            guard inPoint != nil, outPoint != nil else { return self }
        }

        func clampFinite(_ value: Double) -> Double {
            if value.isNaN || value == -.infinity { return 0 }
            if value == .infinity { return duration }
            return min(max(value, 0), duration)
        }

        func nominalFrameDuration() -> Double {
            guard duration > 0 else { return 0 }
            guard frameRate.isFinite, frameRate > 0 else {
                // A bad/unknown nominal rate must not make a valid range
                // collapse to IN == OUT. Use one representable positive step
                // at this duration as a conservative fallback.
                let step = duration.nextUp - duration
                return min(duration, step.isFinite && step > 0 ? step : Double.ulpOfOne)
            }
            let frame = 1 / frameRate
            guard frame.isFinite, frame > 0 else { return duration }
            return min(duration, frame)
        }

        func upperBound(before safeOut: Double) -> Double {
            max(0, safeOut - min(frameDuration, safeOut))
        }

        func upperBoundWithoutOut() -> Double {
            max(0, duration - min(frameDuration, duration))
        }

        func lowerBound(after safeIn: Double) -> Double {
            let available = max(0, duration - safeIn)
            return min(duration, safeIn + min(frameDuration, available))
        }

        let requested = clampFinite(requestedSeconds)
        let frameDuration = nominalFrameDuration()
        var result = self

        switch boundary {
        case .start:
            let safeOut = outPoint.map(clampFinite)
            let startUpperBound: Double
            if let safeOut {
                // Prefer a full nominal frame between IN and OUT. If the
                // existing OUT is too close to the beginning for that, keep
                // the range non-crossing whenever a positive range is possible.
                startUpperBound = upperBound(before: safeOut)
            } else {
                startUpperBound = upperBoundWithoutOut()
            }
            result.inPoint = min(requested, startUpperBound)
            if let outPoint {
                result.outPoint = clampFinite(outPoint)
            }

        case .end:
            // OUT requires IN (guarded above), and the opposite IN stays put.
            let safeIn = clampFinite(inPoint ?? 0)
            let lowerBound = lowerBound(after: safeIn)
            result.inPoint = safeIn
            result.outPoint = max(requested, lowerBound)
        }

        // Snap only the selected endpoint. Clamping after the snap is
        // deliberate: the media duration need not land on a nominal frame.
        if frameRate.isFinite, frameRate > 0, duration > 0 {
            let snapped = (result.inPoint ?? 0) * frameRate
            let snappedStart = snapped.isFinite
                ? min(duration, max(0, (snapped.rounded() / frameRate)))
                : result.inPoint ?? 0
            let snappedEnd = (result.outPoint ?? 0) * frameRate
            let snappedOut = snappedEnd.isFinite
                ? min(duration, max(0, (snappedEnd.rounded() / frameRate)))
                : result.outPoint ?? 0
            switch boundary {
            case .start:
                // Re-apply the crossing clamp after nominal snapping, since
                // rounding can move an endpoint across its neighbour.
                if let safeOut = result.outPoint {
                    result.inPoint = min(snappedStart, upperBound(before: safeOut))
                } else {
                    result.inPoint = min(snappedStart, upperBoundWithoutOut())
                }
            case .end:
                let safeIn = result.inPoint ?? 0
                result.outPoint = max(snappedOut, lowerBound(after: safeIn))
            }
        }

        // Keep every stored endpoint finite and inside the source even when
        // the input draft contained an old non-finite opposite endpoint.
        if let inPoint = result.inPoint {
            result.inPoint = clampFinite(inPoint)
        }
        if let outPoint = result.outPoint {
            result.outPoint = clampFinite(outPoint)
        }
        return result
    }
}
