import Foundation
import TrimletCore

private func requireTimelineViewport(
    _ condition: @autoclosure () -> Bool,
    _ message: String
) {
    guard condition() else {
        FileHandle.standardError.write(Data("FAILED: (message)\n".utf8))
        exit(1)
    }
}

func runTimelineViewportChecks() {
    requireTimelineViewport(
        TimecodeFormatter.string(seconds: 1.0 / 30.0, framesPerSecond: 30) == "00:00:00:01",
        "an exact nominal frame should display the next frame"
    )
    requireTimelineViewport(
        TimecodeFormatter.string(seconds: 2.5 + (1.0 / 30.0), framesPerSecond: 30) == "00:00:02:16",
        "a frame after a fractional second should not lose one frame to floating-point error"
    )
    requireTimelineViewport(
        TimecodeFormatter.string(seconds: 2.5 + (1.0 - 1e-6) / 30.0, framesPerSecond: 30) == "00:00:02:15",
        "a true sub-frame position should not be rounded up"
    )

    let full = TimelineViewport.full(duration: 100)
    requireTimelineViewport(full.duration == 100, "full viewport should retain duration")
    requireTimelineViewport(full.start == 0 && full.span == 100, "full viewport should cover media")
    requireTimelineViewport(full.end == 100, "full viewport should end at media duration")

    let zero = TimelineViewport(duration: 0, start: 12, span: 5)
    requireTimelineViewport(zero == TimelineViewport.full(duration: 0), "zero duration should normalize to zero viewport")
    let negative = TimelineViewport(duration: -1, start: -4, span: -2)
    requireTimelineViewport(negative == TimelineViewport.full(duration: 0), "negative duration should normalize safely")
    let nonFinite = TimelineViewport(duration: .infinity, start: .nan, span: .infinity)
    requireTimelineViewport(nonFinite == TimelineViewport.full(duration: 0), "non-finite values should not leak into viewport")

    let bounded = TimelineViewport(duration: 10, start: -2, span: 20)
    requireTimelineViewport(bounded.start == 0 && bounded.span == 10, "viewport should clamp start and span")
    let tail = TimelineViewport(duration: 10, start: 9, span: 3)
    requireTimelineViewport(tail.start == 7 && tail.end == 10, "viewport should clamp to right media boundary")

    let view = TimelineViewport(duration: 100, start: 20, span: 40)
    requireTimelineViewport(view.fraction(for: 0) == 0, "times before viewport should map to zero")
    requireTimelineViewport(view.fraction(for: 20) == 0, "viewport start should map to zero")
    requireTimelineViewport(view.fraction(for: 40) == 0.5, "midpoint should map to half")
    requireTimelineViewport(view.fraction(for: 60) == 1, "viewport end should map to one")
    requireTimelineViewport(view.fraction(for: 100) == 1, "times after viewport should map to one")
    requireTimelineViewport(view.fraction(for: .nan) == 0, "non-finite time should map safely")
    requireTimelineViewport(view.time(at: -1) == 20, "fractions below zero should map to start")
    requireTimelineViewport(view.time(at: 0.5) == 40, "fraction-to-time mapping should round trip midpoint")
    requireTimelineViewport(view.time(at: 2) == 60, "fractions above one should map to end")
    requireTimelineViewport(view.time(at: .infinity) == 20, "non-finite fraction should map safely")

    let zoomed = view.zoomed(by: 2, anchor: 0.25, minimumSpan: 1)
    requireTimelineViewport(zoomed.span == 20, "factor two should halve the span")
    requireTimelineViewport(zoomed.time(at: 0.25) == view.time(at: 0.25), "fraction anchor time should remain stable")
    let zoomedAtTime = view.zoomed(by: 2, anchorTime: 30, minimumSpan: 1)
    requireTimelineViewport(zoomedAtTime.time(at: 0.25) == 30, "absolute-time anchor should remain stable")
    let minZoom = view.zoomed(by: 1000, anchor: 0.5, minimumSpan: 25)
    requireTimelineViewport(minZoom.span == 25, "zoom should honor minimum span")
    let maxZoom = view.zoomed(by: 0.01, anchor: 0.5, minimumSpan: 1)
    requireTimelineViewport(maxZoom == TimelineViewport.full(duration: 100), "zoom out should cap at full media")
    requireTimelineViewport(view.zoomed(by: .nan) == view, "non-finite zoom factor should be a no-op")

    requireTimelineViewport(view.panned(by: 15).start == 35, "positive pan should move later")
    requireTimelineViewport(view.panned(by: -100).start == 0, "pan should clamp at start")
    requireTimelineViewport(view.panned(by: 100).end == 100, "pan should clamp at end")
    requireTimelineViewport(view.panned(by: Double.greatestFiniteMagnitude).end == 100, "a huge finite pan should still clamp at end")
    requireTimelineViewport(view.panned(by: .infinity) == view, "non-finite pan should be a no-op")

    requireTimelineViewport(view.revealing(10).start == 10, "reveal should move left for an earlier time")
    requireTimelineViewport(view.revealing(90).start == 50, "reveal should move right for a later time")
    requireTimelineViewport(view.revealing(40) == view, "visible time should not move viewport")
    requireTimelineViewport(view.revealing(.nan) == view, "non-finite reveal time should be a no-op")

    let snapped = TimelineViewport.full(duration: 10).snapping(1.24, toFrameRate: 30)
    requireTimelineViewport(abs(snapped - (37.0 / 30.0)) < 0.000_001, "time should snap to nearest nominal frame")
    requireTimelineViewport(TimelineViewport.full(duration: 10).snapping(99, toFrameRate: 30) == 10, "snapped time should clamp to duration")

    let draft = TrimRange(inPoint: 2, outPoint: 8)
    let movedStart = draft.movingBoundary(.start, to: 3.2, duration: 10, frameRate: 30)
    requireTimelineViewport(abs((movedStart.inPoint ?? -1) - 3.2) < 0.000_001, "IN should snap to the nominal frame")
    requireTimelineViewport(movedStart.outPoint == 8, "moving IN should preserve OUT")
    let crossingStart = draft.movingBoundary(.start, to: 9, duration: 10, frameRate: 30)
    requireTimelineViewport(abs((crossingStart.inPoint ?? -1) - (8 - 1.0 / 30.0)) < 0.000_001, "crossing IN should clamp one frame before OUT")
    requireTimelineViewport(crossingStart.outPoint == 8, "crossing IN should not move OUT")

    let movedEnd = draft.movingBoundary(.end, to: 4.2, duration: 10, frameRate: 30)
    requireTimelineViewport(abs((movedEnd.outPoint ?? -1) - 4.2) < 0.000_001, "OUT should snap to the nominal frame")
    requireTimelineViewport(movedEnd.inPoint == 2, "moving OUT should preserve IN")
    let crossingEnd = draft.movingBoundary(.end, to: 1, duration: 10, frameRate: 30)
    requireTimelineViewport(abs((crossingEnd.outPoint ?? -1) - (2 + 1.0 / 30.0)) < 0.000_001, "crossing OUT should clamp one frame after IN")
    requireTimelineViewport(crossingEnd.inPoint == 2, "crossing OUT should not move IN")

    let edge = TrimRange(inPoint: 9.99, outPoint: 10)
    let oneFrameEdge = edge.movingBoundary(.start, to: 10, duration: 10, frameRate: 30)
    requireTimelineViewport((oneFrameEdge.inPoint ?? -1) <= 10, "IN should remain inside duration at the end")
    requireTimelineViewport(oneFrameEdge.outPoint == 10, "one-frame edge move should preserve OUT")
    let belowOneFrame = TrimRange(inPoint: 0, outPoint: 0.01)
        .movingBoundary(.start, to: 0.02, duration: 1, frameRate: 30)
    requireTimelineViewport(belowOneFrame.inPoint == 0, "a sub-frame range should clamp IN to the source start")
    requireTimelineViewport(belowOneFrame.isValid, "a sub-frame range should remain strictly valid")
    let belowOneFrameAtEnd = TrimRange(inPoint: 0.99, outPoint: 1)
        .movingBoundary(.end, to: 0, duration: 1, frameRate: 30)
    requireTimelineViewport(belowOneFrameAtEnd.outPoint == 1, "a sub-frame range at the end should preserve OUT")
    requireTimelineViewport(belowOneFrameAtEnd.isValid, "a sub-frame range at the end should remain strictly valid")
    let startOnly = TrimRange(inPoint: 0.5)
        .movingBoundary(.start, to: 10, duration: 1, frameRate: 30)
    requireTimelineViewport((startOnly.inPoint ?? 1) <= 1 - 1.0 / 30.0, "a start without OUT should leave room for one frame")
    let clampedEnd = draft.movingBoundary(.end, to: 99, duration: 10, frameRate: 30)
    requireTimelineViewport(clampedEnd.outPoint == 10, "OUT should clamp to source duration")
    let clampedStart = draft.movingBoundary(.start, to: -99, duration: 10, frameRate: 30)
    requireTimelineViewport(clampedStart.inPoint == 0, "IN should clamp to source start")

    let missingStart = TrimRange(outPoint: 4).movingBoundary(.start, to: 2, duration: 10, frameRate: 30)
    requireTimelineViewport(missingStart == TrimRange(outPoint: 4), "moving a missing IN should be a no-op")
    let missingOut = TrimRange(inPoint: 2).movingBoundary(.end, to: 4, duration: 10, frameRate: 30)
    requireTimelineViewport(missingOut == TrimRange(inPoint: 2), "moving a missing OUT should be a no-op")
    let outWithoutIn = TrimRange(outPoint: 4).movingBoundary(.end, to: 2, duration: 10, frameRate: 30)
    requireTimelineViewport(outWithoutIn == TrimRange(outPoint: 4), "OUT should require IN")

    let invalidSourceRange = TrimRange(inPoint: 2, outPoint: 4)
    requireTimelineViewport(
        invalidSourceRange.movingBoundary(.start, to: 3, duration: .nan, frameRate: 30) == invalidSourceRange,
        "an invalid source duration should leave the range unchanged"
    )
    let nonFiniteRequest = draft.movingBoundary(.end, to: .nan, duration: 10, frameRate: 30)
    requireTimelineViewport(nonFiniteRequest.inPoint?.isFinite == true, "non-finite request should not create NaN IN")
    requireTimelineViewport(nonFiniteRequest.outPoint?.isFinite == true, "non-finite request should not create NaN OUT")
    let invalidRate = draft.movingBoundary(.start, to: 99, duration: 10, frameRate: .nan)
    requireTimelineViewport(invalidRate.isValid, "an invalid nominal rate should still preserve strict validity")

    // 29.97 is a nominal display rate here; this deliberately does not claim
    // that a nominal snap is a VFR frame-index lookup.
    let nominalVFR = draft.movingBoundary(.end, to: 4.003, duration: 10, frameRate: 29.97)
    let expectedNominal = (4.003 * 29.97).rounded() / 29.97
    requireTimelineViewport(abs((nominalVFR.outPoint ?? -1) - expectedNominal) < 0.000_001, "VFR media should use nominal frame snapping only")
}
