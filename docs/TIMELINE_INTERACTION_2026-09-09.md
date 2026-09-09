# Source timeline interaction specification — build 10

- Date: 2026-09-09
- Status: Implemented in the Mac build 10 development candidate; Mac human verification pending
- Scope: Mac build 10 first, with the interaction semantics handed to the Windows implementation
- Supersedes: the build 9 split-row boundary geometry in `docs/TIMELINE_SEEK_FIX_2026-09-09.md`

This document is the canonical specification for the source timeline's playhead,
IN/OUT boundaries, hit testing, and feedback. Earlier documents and screenshots
remain useful history, but their boundary geometry must not be used to implement
build 10 when it differs from this document.

The production drawing components have been rendered offscreen in light and dark
appearances for a four-state visual smoke check (normal, very short, IN-only, and
edge ranges): [light component render](images/timeline-build10-light.png) and
[dark component render](images/timeline-build10-dark.png). These are generated
component renders, not screenshots of the running application and not a human
gesture-acceptance result.

## User mental model

The source timeline has one time axis and two kinds of objects on it:

1. The upper ruler has one white playhead. It answers “where am I looking or
   playing now?”
2. The lower lane has one selected source range. Its left and right ends answer
   “what will become the subclip?”

Successful IN or OUT setting records the current position; it does not start playback. In
the normal valid-range flow, setting IN leaves the later OUT unchanged. If the
new IN would make an existing OUT invalid, the OUT is cleared and the UI must
make that state visible; it must not silently claim that the range is still
valid. After setting IN, a user can stop and move the playhead on the timeline
before setting OUT. Playback is not required for this workflow.

## Geometry

The timeline control is a compact 84 pt-high surface with horizontal content
gutters of 24 pt on both sides. The gutters are part of the layout, not a time
extension: source timestamps still map only to the content interval.

| Local vertical area | Range | Purpose |
|---|---:|---|
| Upper ruler/playhead lane | `0–38 pt` | Source ticks, keyframes, and playhead; all non-handle pointer input seeks |
| Separation | `38–40 pt` | Visual and hit-test separation |
| Lower range lane | `40–72 pt` | One draft/retained range and its IN/OUT boundary grips |
| Lower breathing room | `72–84 pt` | Labels/tooltips and visual clearance |

The exact source-to-x mapping is unchanged by this layout. A timestamp at the
first source position maps to the left content edge and the duration maps to the
right content edge. The 24 pt gutters provide room for an outward grip when a
boundary is at the edge; they must not shift, clamp, or falsify the timestamp.

### Playhead

- Draw a white vertical line through both lanes at the current source position.
- Draw a downward-facing white triangle in the upper lane, centered on that line.
- The triangle and line are a playhead indicator, not a draggable IN/OUT handle.
- A click or drag in any non-handle part of the timeline seeks the playhead.
- During a drag, use the existing responsive/coalesced preview seek; on release,
  perform the exact final seek to the displayed timestamp.

### Selected range and boundaries

- Render one continuous lower-lane range at its true time coordinates. Do not
  invent a minimum visual width or move a boundary to make a short range look
  wider.
- A valid uncommitted range uses the existing translucent purple fill and dashed
  purple boundary. A committed retained range remains blue.
- Draw IN as the green left boundary and OUT as the red right boundary. Both
  boundary grips are in the same lower-lane height and face outward, so the left
  grip visually points left and the right grip points right.
- Give the IN grip the exclusive outward hit area `[xIN - 24 pt, xIN)` and the
  OUT grip the exclusive outward hit area `[xOUT, xOUT + 24 pt)`. The intervals
  are half-open and therefore do not overlap, even when the selected range is
  narrower than 48 pt.
- Keep the visible boundary at the true `xIN`/`xOUT`; the outward hit area is
  invisible padding, not an extra timeline segment.
- When a boundary is at a content edge, the horizontal gutter keeps its outward
  hit area visible without changing the time mapping.

## Hit testing and drag semantics

Hit testing is decided once at pointer-down and remains latched for that gesture.
This prevents the pointer from changing roles while it crosses a narrow range.

Priority and behavior:

1. If the pointer is inside the exclusive IN grip, drag IN only.
2. Else if it is inside the exclusive OUT grip, drag OUT only.
3. Else, click/drag seeks the playhead only.

Boundary dragging uses the pointer translation from the boundary timestamp at
pointer-down. Grabbing the padded outward portion must not jump the boundary to
the pointer's x-coordinate. While dragging, show the provisional boundary time
and preview frame; apply the same range constraints as keyboard/button editing:
IN cannot reach or pass OUT, OUT cannot reach or pass IN, and neither can leave
the source duration.

There is no whole-range slip gesture in build 10. Dragging inside the purple or
blue fill seeks; it never moves both boundaries. Existing-clip boundary changes
remain a draft until the explicit trim-apply command; applying the completed
trim is one Undo unit. New-subclip draft gestures are session state and are not
stored in the project document.

## Buttons, shortcuts, and feedback

- `I` / `INを設定`: set IN to the current source position.
- `O` / `OUTを設定`: set OUT to the current source position.
- Show the `I` and `O` keycaps beside the corresponding buttons at all times.
- A button or shortcut must work while paused; it must not require a play command.
- If a range is invalid, state the reason next to the action (for example,
  “OUTはINより後に設定してください”) rather than making the control appear
  dead.
- On hover, identify the target (`再生位置を移動`, `INを調整`, or `OUTを調整`)
  and show the corresponding time when practical.
- During a boundary drag, keep the IN/OUT labels, current time, and provisional
  range visible. Do not hide the range behind a transient overlay.
- Preserve two-finger trackpad seeking. It remains a seek gesture in this
  milestone; zoom/pan or a hover-scrubber is out of scope.

## State presentation

| State | Lower-lane presentation | Available timeline actions |
|---|---|---|
| No boundary | No selected range; source marks only | Seek, set IN |
| IN only | Green IN boundary; no fill | Seek, set OUT, move IN grip |
| Valid IN + OUT draft | Purple fill and dashed purple boundary; green IN/red OUT | Seek, adjust either boundary, add to sequence |
| Retained range | Blue fill; green/red source boundaries as applicable | Seek; explicit Trim Edit before changing a retained clip |
| Boundary drag | Same draft/retained presentation plus provisional time feedback | Only the latched boundary changes |

Color is not the sole state cue: line style, boundary shape, labels, and the
visible `I`/`O` controls remain available in light and dark appearances.

## Non-goals and compatibility

- No schema or `.trimlet` project-format change is required. Playhead position,
  draft range, hit-test state, hover feedback, and preview proxy state remain
  session-only.
- No arbitrary sequence-time placement, gaps, overlaps, whole-range slip,
  multi-track editing, waveform, or hover-skimmer is introduced.
- Nominal-fps snapping and VFR timestamp storage retain their existing meanings.
- Mac and Windows must expose the same roles, range constraints, and shortcut
  meanings, but may use platform-native drawing and pointer APIs.

## Implementation verification snapshot

The Mac build 10 development candidate has been built and its new geometry and
pointer model are covered by the CoreChecks suite, including the exclusive grip
intervals, pointer-down target latching, no-jump translation, edge gutters, and
range constraints. Shared contract validation and the application bundle's
debug/release build and signature checks also pass. The existing integration
regression command, `swift run --package-path apps/macos
TrimletIntegrationChecks`, passes the reordered three-range export cases
(Accurate `3.800 s`, Fast `10.000 s`).

The four-state light/dark component render smoke check is available as
[light](images/timeline-build10-light.png) and [dark](images/timeline-build10-dark.png).
These are offscreen component renders, not screenshots of the running
application. Pointer and trackpad behavior, layout in the actual app window,
and user comprehension remain a human-check gate.

## Build 10 human-check gate

The Mac check is pending until a user performs all of the following on a normal
range and on a very short range:

1. Set IN while paused, move the playhead by upper-lane click/drag without
   starting playback, and confirm IN stays fixed.
2. Set OUT after that move and confirm the selected range becomes purple and the
   Add action becomes available.
3. Click/drag the purple fill and an empty timeline area and confirm only the
   playhead moves; neither boundary moves.
4. Drag the visible IN and OUT ends and confirm only the latched boundary moves,
   with no jump on the padded grip and no crossing of the opposite boundary.
5. Use a range narrower than the two 24 pt grip areas and confirm both grips are
   still independently targetable.
6. Use `I` and `O`, the visible buttons, and two-finger seeking; confirm their
   behavior agrees and no action requires playback.
7. Confirm hover/drag feedback identifies the target and time, and that the
   range remains readable in light and dark appearances.

Automated tests should cover the exclusive hit intervals, pointer-down latching,
translation-without-jump, edge gutters, range constraints, and unchanged project
serialization. A passing build or unit test is not a substitute for this visual
and gesture check.
