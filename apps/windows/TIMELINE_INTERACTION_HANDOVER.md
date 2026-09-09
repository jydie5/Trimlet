# Mac → Windows: source timeline interaction, development build 10

Windows update, 2026-09-09: implemented in Windows development source. See
[the return and verification record](BUILD10_PARITY_RETURN.md). The Mac
preparation and acceptance record below remains historical and unchanged.

Prepared 2026-09-09. This is an implementation handover, **not a release or
human-acceptance announcement**. Windows implementation was not modified in this
task. This handover accompanies the Mac build 10 source update. Pull the latest
main and consult the Git history before starting parity work; no new binary
release or Windows implementation is implied by this source update.

## Read first

- [Canonical interaction specification](../../docs/TIMELINE_INTERACTION_2026-09-09.md)
- [Shared platform contract](../../docs/PLATFORM_CONTRACT.md)
- [Verification status](../../docs/VERIFICATION.md)
- [Project persistence handover](PROJECT_PERSISTENCE_HANDOVER.md)
- [Mac playback compatibility investigation](../../docs/PLAYBACK_COMPATIBILITY_2026-09-09.md)

## Why the interaction changed

The old IN handle overlaid the playhead immediately after marking IN. A user
trying to scrub instead dragged IN and the preview position together, so OUT
was then rejected as not later than IN. Build 9 separated the handles into two
rows as a temporary fix. **Do not port that temporary three-level arrangement.**
Build 10 represents a single range with two outward grips, below a distinct
playhead/ruler lane.

## Port the semantics, use native WinUI input

1. Upper lane: downward playhead triangle and vertical line, independent of IN/OUT.
2. Lower lane: purple dashed draft range; blue retained clips. IN and OUT are
   same-height outward brackets, with labels as well as green/red colors.
3. Mac reference dimensions: height84pt, content inset24pt, lower hit lane40–72pt.
   IN occupies `[xIN-24,xIN)` and OUT `[xOUT,xOUT+24)`. Keep hit areas disjoint,
   including one-frame and visually subpixel ranges. Adapt logical sizing to
   Windows DPI; do not shift source positions to make handles fit.
4. Capture the pointer and latch the target at pointer-down. Moving across a
   different object must never change the operation mid-drag.
5. Boundary movement is based on the initial boundary plus pointer translation,
   not the padded grip's absolute x position. A zero-distance click previews the
   boundary without re-snapping or modifying it.
6. Any non-handle click/drag, including the range fill, only seeks. There is no
   whole-range slip gesture. Two-finger scrolling also only seeks.
7. Keep IN stable while scrubbing to OUT. I/O and the visible buttons work paused;
   playback is not a prerequisite. Existing policy: setting IN at/after OUT
   clears the invalid OUT; setting OUT at/before IN is rejected with an inline
   explanation. Boundary drags clamp against the other endpoint.
8. Show target and time feedback while hovering/dragging. Preserve frame/second
   navigation, JKL, and visible I/O hints. Existing-clip trimming remains a draft
   until Apply; Apply, not each draft movement, creates the committed Undo unit.

Do not copy SwiftUI gesture code literally. Implement the same routing with
WinUI pointer capture and robust pointer-cancel/lost-capture handling. Do not
allow delayed preview-seek callbacks to overwrite a newer pointer target.

## Mac reference files and checks

- `apps/macos/Sources/TrimletCore/TimelineInteractionLayout.swift`: pure mapping,
  outward hit intervals, visibility and translation calculations.
- `apps/macos/Checks/TrimletCoreChecks/TimelineInteractionChecks.swift`: fixtures
  to reproduce in Windows tests (zoom, edges, tiny ranges, coincident endpoints,
  offscreen handles, nonfinite inputs and no-jump translation).
- `apps/macos/Sources/Trimlet/SourceTimeline.swift`: latched gesture ownership,
  feedback, boundary versus seek dispatch and accessibility adjustment.
- `RangeBar.swift` / `DraftRangeGrip.swift`: production drawing components.
- [Light component render](../../docs/images/timeline-build10-light.png)
  / [Dark component render](../../docs/images/timeline-build10-dark.png).
  These are offscreen renders of production drawing components, **not screenshots
  proving pointer interaction or whole-window layout**.

## Compatibility boundaries

- No `.trimlet` schema, edit-list ordering, OUT-exclusive convention, encoding
  arguments or source identity changes in this timeline task.
- Draft IN/OUT, playhead and hover/drag state remain session-only. Saving a project
  does not preserve an uncommitted draft.
- Mac boundary adjustment still uses nominal-fps snapping. Do not regress the
  Windows source-presentation-timestamp support to match this Mac limitation.
- Mac now checks actual AVFoundation playability before accepting a source and
  falls back to a cached H.264/AAC preview. Preserve the original for exports;
  Fast preserves its video codec while Accurate aims for H.264/AAC output.
  Windows should retain its own validated fallback rather than hardcode VP9.

## Acceptance / outstanding work

Mac Debug and Release build, Core checks (including new geometry checks), shared
contracts, bundle executable permission and ad-hoc signature verification passed.
Main reviewed the four component-render states in both color schemes.
The generated-media integration check also passed (Accurate 3.800s, Fast 10.000s).
Mac live UI validation is still pending: the computer-use connection timed out
after the project-save dialog. This is not Windows validation and not a human
acceptance result.

Windows must demonstrate paused IN → scrub → OUT, independent endpoint drags,
no jumps when grabbing padded areas, narrow and source-edge ranges, zoom,
trackpad/keyboard parity, lost pointer capture, purple → blue after Add, and
unchanged project/export behavior. Record actual Windows results before marking
the feature caught up. Keep the two platform acceptance records separate.
