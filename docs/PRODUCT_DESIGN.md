# Trimlet product and interface design principles

- Status: Accepted for PoC and Early Access; build 10 timeline implemented in the Mac development candidate
- Updated: 2026-09-09

Trimlet is a focused desktop utility for collecting and ordering useful ranges from one local video. It is not a landing page, media library, or full multi-track editor.

## Product promise

Open one video, find and order the useful ranges, save the work, and export without altering the source.

The public tagline, “Only what you need, quickly and precisely.” / 「必要なところだけ、すばやく正確に。」, summarizes that promise in repository, release, and About material. It is not a required heading inside the working canvas.

## Interface priorities

1. Media first: the video, current position, and selected range occupy the strongest visual area.
2. One primary next action: empty state emphasizes Open; loaded state emphasizes setting a range; a valid draft emphasizes Add; a retained sequence emphasizes Preview, Save, and Export.
3. Show explanations only when they affect the next decision, such as Fast keyframe movement, Accurate re-encoding, or a recoverable error.
4. Prefer direct labels and visible state over tutorial prose permanently occupying the window.
5. Keep diagnostics, full paths, codec detail, and implementation language out of the normal work surface; expose them on demand or in logs.
6. Native, not identical: macOS and Windows use their platform conventions while keeping the same workflow and terminology.

## Stable work states

| State | Essential content |
|---|---|
| Empty | drop/open target and supported input types |
| Loading | concise progress or activity indication |
| Loaded | preview, position, navigation, source identity, IN/OUT actions |
| Range ready | IN, OUT, duration, range preview, Fast/Accurate choice, export |
| Project dirty | project identity plus a compact unsaved marker and conventional Save command |
| Relink needed | expected source name, choose-source action, mismatch warning, cancel |
| Exporting | progress, current mode, cancel |
| Completed | result, reveal action |
| Failed | short cause, recovery action, diagnostics location when useful |

Routine success notices should not displace the media. Persistent copy must earn its space by changing what the user does next.

## Source timeline interaction (build 10)

The source timeline uses one clear time axis with two visual layers: an upper
ruler/playhead lane and one lower IN/OUT range lane. The upper lane is the
unambiguous seek surface. The lower lane is the range surface, with outward
boundary grips for editing. The playhead is a white downward triangle and line;
the draft range is purple with a dashed boundary; retained ranges are blue.

The timeline is 84 pt high with 24 pt horizontal content gutters. IN and OUT
grips have exclusive 24 pt outward hit areas (`[xIN-24,xIN)` and
`[xOUT,xOUT+24)`) at the same lower-lane height. A pointer-down latches its
role: a boundary grip edits only that boundary, while every other click or drag
seeks only the playhead. Boundary translation is measured from the initial
pointer position so grabbing an outward padded grip never jumps the boundary.
The range is drawn at its true time coordinates, even when it is very short.

This separation addresses the build 9 failure mode in which the playhead and
IN/OUT controls occupied competing rows or overlapped visually. It does not add
a whole-range slip gesture or alter the `.trimlet` schema. See the canonical
[timeline interaction specification](TIMELINE_INTERACTION_2026-09-09.md). The
associated [light component render](images/timeline-build10-light.png) and
[dark component render](images/timeline-build10-dark.png) are visual smoke
evidence only; they are not screenshots of the running app or a gesture
acceptance result.

## Cross-platform consistency

The platforms share:

- the open → navigate → IN → OUT → preview → export sequence;
- exclusive OUT semantics and source-timestamp-based contracts;
- Fast and Accurate meanings;
- source safety, cancellation, validation, and error categories;
- Japanese and English product terminology.

They do not need identical spacing, controls, title bars, dialogs, media frameworks, or platform shortcuts. A visual change becomes a shared decision only when it changes the workflow, terminology, timing semantics, or safety guarantees.

## Release review questions

Before merging an interface change, ask:

1. Does this text help the current task, or does it belong in README/About/help?
2. Is the next action obvious without reading a paragraph?
3. Does the video and selected range remain visually dominant?
4. Is the same behavior described consistently on both platforms?
5. Are technical details available without becoming permanent UI noise?
6. Can a paused user set IN, seek in the upper lane, and set OUT without
   accidentally moving a boundary—also for a very short range?
