import Foundation
import TrimletCore

private func requireTimelineInteraction(
    _ condition: @autoclosure () -> Bool,
    _ message: String
) {
    guard condition() else {
        FileHandle.standardError.write(Data("FAILED: \(message)\n".utf8))
        exit(1)
    }
}

func runTimelineInteractionChecks() {
    let fullViewport = TimelineViewport.full(duration: 100)
    let full = TimelineInteractionLayout(width: 600, viewport: fullViewport)

    requireTimelineInteraction(TimelineInteractionLayout.height == 84, "timeline height should be 84 points")
    requireTimelineInteraction(TimelineInteractionLayout.gutter == 24, "timeline gutter should be 24 points")
    requireTimelineInteraction(TimelineInteractionLayout.gripWidth == 24, "boundary grip width should be 24 points")
    requireTimelineInteraction(full.inset == 24, "content should start after the leading gutter")
    requireTimelineInteraction(full.contentWidth == 552, "content width should exclude both gutters")

    // Full-viewport mapping uses only the content interval; the gutters clamp
    // to the source edges and never introduce extra media time.
    requireTimelineInteraction(full.x(for: 0) == 24, "source start should map to the leading content edge")
    requireTimelineInteraction(full.x(for: 50) == 300, "the full viewport midpoint should map to the content midpoint")
    requireTimelineInteraction(full.x(for: 100) == 576, "source duration should map to the trailing content edge")
    requireTimelineInteraction(full.time(at: 0) == 0, "leading gutter should map to source start")
    requireTimelineInteraction(full.time(at: 24) == 0, "leading content edge should map to source start")
    requireTimelineInteraction(full.time(at: 300) == 50, "content midpoint should map back to source midpoint")
    requireTimelineInteraction(full.time(at: 576) == 100, "trailing content edge should map to source duration")
    requireTimelineInteraction(full.time(at: 600) == 100, "trailing gutter should map to source duration")

    let zoomedViewport = TimelineViewport(duration: 100, start: 25, span: 10)
    let zoomed = TimelineInteractionLayout(width: 600, viewport: zoomedViewport)
    requireTimelineInteraction(zoomed.x(for: 25) == 24, "zoomed viewport start should map to the content edge")
    requireTimelineInteraction(zoomed.x(for: 30) == 300, "zoomed viewport midpoint should map to the content midpoint")
    requireTimelineInteraction(zoomed.x(for: 35) == 576, "zoomed viewport end should map to the content edge")
    requireTimelineInteraction(zoomed.time(at: 24) == 25, "zoomed content start should map to viewport start")
    requireTimelineInteraction(zoomed.time(at: 576) == 35, "zoomed content end should map to viewport end")

    // Lower-lane hit testing uses exclusive outward grips.  A short range
    // still leaves both ends independently targetable.
    let narrowIn = 40.0
    let narrowOut = 40.25
    let narrowInX = full.x(for: narrowIn)
    let narrowOutX = full.x(for: narrowOut)
    requireTimelineInteraction(
        full.target(x: narrowInX - 0.1, y: 50, inPoint: narrowIn, outPoint: narrowOut) == .start,
        "the narrow range IN grip should be targetable"
    )
    requireTimelineInteraction(
        full.target(x: narrowInX, y: 50, inPoint: narrowIn, outPoint: narrowOut) == .seek,
        "the space between narrow grips should seek"
    )
    requireTimelineInteraction(
        full.target(x: narrowOutX, y: 50, inPoint: narrowIn, outPoint: narrowOut) == .end,
        "the narrow range OUT grip should be targetable"
    )

    // At coincident endpoints the half-open intervals do not overlap: the
    // exact boundary belongs to OUT, while the preceding padded space belongs
    // to IN.
    let coincident = full.x(for: 50)
    requireTimelineInteraction(
        full.target(x: coincident - 0.1, y: 50, inPoint: 50, outPoint: 50) == .start,
        "coincident endpoint padding should target IN before the boundary"
    )
    requireTimelineInteraction(
        full.target(x: coincident, y: 50, inPoint: 50, outPoint: 50) == .end,
        "coincident endpoint boundary should target OUT at the half-open edge"
    )

    // The upper lane, separator, and lower-lane body are all seek surfaces;
    // only the exclusive grips take a boundary role.
    requireTimelineInteraction(
        full.target(x: coincident - 0.1, y: 20, inPoint: 50, outPoint: 50) == .seek,
        "the upper lane should always seek"
    )
    requireTimelineInteraction(
        full.target(x: coincident, y: 39, inPoint: 50, outPoint: 50) == .seek,
        "the separator should seek"
    )
    requireTimelineInteraction(
        full.target(x: coincident + 40, y: 50, inPoint: 50, outPoint: 50) == .seek,
        "the lower range body should seek"
    )
    requireTimelineInteraction(
        full.target(x: coincident, y: 72, inPoint: 50, outPoint: 50) == .seek,
        "the lower lane's bottom edge should seek"
    )

    // An off-screen boundary must not be clamped to a visible edge for hit
    // testing.  It is not targetable until the viewport reveals it.
    requireTimelineInteraction(
        zoomed.target(x: zoomed.x(for: 25) - 0.1, y: 50, inPoint: 5, outPoint: 95) == .seek,
        "off-screen boundaries should never receive a grip hit"
    )

    // Translation is relative to the initial source time, not the pointer's
    // absolute x.  A zero delta therefore never jumps the boundary.
    requireTimelineInteraction(full.translatedTime(from: 50, deltaX: 0) == 50, "zero translation should preserve the initial time")
    requireTimelineInteraction(full.translatedTime(from: 50, deltaX: full.contentWidth) == 100, "one content width should translate by the viewport span")
    requireTimelineInteraction(full.translatedTime(from: 50, deltaX: -full.contentWidth) == 0, "negative translation should clamp at source start")
    requireTimelineInteraction(zoomed.translatedTime(from: 30, deltaX: zoomed.contentWidth) == 40, "zoomed translation should use viewport span")

    let hugeForward = full.translatedTime(from: 50, deltaX: .greatestFiniteMagnitude)
    let hugeBackward = full.translatedTime(from: 50, deltaX: -.greatestFiniteMagnitude)
    requireTimelineInteraction(hugeForward == 100, "huge positive translation should clamp to source duration")
    requireTimelineInteraction(hugeBackward == 0, "huge negative translation should clamp to source start")
    requireTimelineInteraction(full.translatedTime(from: 50, deltaX: .nan) == 50, "NaN translation should preserve the initial time")
    requireTimelineInteraction(full.translatedTime(from: .nan, deltaX: 0) == 0, "NaN initial time should resolve safely")
    requireTimelineInteraction(full.translatedTime(from: .infinity, deltaX: 0) == 100, "infinite initial time should clamp to source duration")

    let invalidWidth = TimelineInteractionLayout(width: .nan, viewport: fullViewport)
    requireTimelineInteraction(invalidWidth.width == 0, "non-finite width should normalize to zero")
    requireTimelineInteraction(invalidWidth.contentWidth == 0, "invalid width should have no time-mapped content")
    requireTimelineInteraction(invalidWidth.x(for: 50).isFinite, "invalid width mapping should remain finite")
    requireTimelineInteraction(invalidWidth.time(at: .infinity).isFinite, "invalid width inverse mapping should remain finite")
    requireTimelineInteraction(invalidWidth.translatedTime(from: 50, deltaX: 20) == 50, "zero content width should ignore translation")
}
