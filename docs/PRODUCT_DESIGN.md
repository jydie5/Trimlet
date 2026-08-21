# Trimlet product and interface design principles

- Status: Accepted for PoC and Early Access
- Updated: 2026-08-21

Trimlet is a focused desktop utility for cutting one useful range from one local video. It is not a landing page, media library, or full timeline editor.

## Product promise

Open one video, find the boundaries, and export the range without altering the source.

The public tagline, “Only what you need, quickly and precisely.” / 「必要なところだけ、すばやく正確に。」, summarizes that promise in repository, release, and About material. It is not a required heading inside the working canvas.

## Interface priorities

1. Media first: the video, current position, and selected range occupy the strongest visual area.
2. One primary next action: empty state emphasizes Open; loaded state emphasizes setting the range; valid range emphasizes Export.
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
| Exporting | progress, current mode, cancel |
| Completed | result, reveal action |
| Failed | short cause, recovery action, diagnostics location when useful |

Routine success notices should not displace the media. Persistent copy must earn its space by changing what the user does next.

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
