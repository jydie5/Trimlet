# Windows multi-range parity handover for the macOS owner

- Prepared: 2026-08-28
- Mac baseline reviewed: `v0.3.0-beta.1`
- Windows state: caught up in source; broad Windows release validation pending

## What Windows adopted

Windows now implements the shared one-source, ordered multi-range contract rather than the Early Access single-range workflow:

1. A three-stage IN → OUT → Add flow with an empty draft after source open and after a successful add.
2. A purple, dashed draft distinct from blue retained clips, with a visible legend and separate IN/OUT/Fast/keyframe markers.
3. Stable clip identity, editable names, representative thumbnails, source boundaries, selection-only card clicks, and explicit Trim Edit.
4. Delete, earlier/later, drag reorder, Undo/Redo, selected-clip preview, and continuous sequence preview.
5. Discoverable I/O controls, signed J/K/L shuttle levels, responsive scrub updates, and a final seek on release.
6. Ordered multi-range Fast and Accurate export through temporary per-segment files, concat, combined progress, validation, and cleanup.

Windows consumes `contracts/edit-list.schema.json` and `contracts/fixtures/edit-list-cases.json`. The shared non-overlap rule is applied in source time even when output order differs.

## Native Windows choices

- WinUI 3 and `MediaPlayerElement` remain the preview layer; no SwiftUI or AVPlayer code was copied.
- Forward shuttle uses native playback rates. Reverse shuttle uses a wall-clock-paced seek fallback because Windows MediaPlayer does not provide negative playback rates for this path.
- Clip thumbnails are generated asynchronously with FFmpeg into a per-session cache and are not part of the export model.
- Fast export stream-copies each keyframe-compatible segment, then concatenates those files without video re-encoding. Accurate export encodes each requested segment before concatenation.
- The audio picker is hidden for single-audio media and shown for multi-audio media.
- M2TS/MTS and direct-playback failures use a validated, cancellable H.264/AAC preview proxy while source identity and export input remain original.
- Frame movement uses source presentation timestamps after a non-modal background frame index is ready, with nominal-rate stepping only during analysis.

## Verification returned to macOS

- Shared contract and Windows unit tests cover edit-list identity, move/update/delete, half-open adjacency, overlap rejection, ordered multi-range plans, proxy plans/cache identity, and irregular presentation-timestamp stepping.
- Generated-media integration checks cover reordered three-segment Fast and Accurate output, actual color order, selected non-default audio, source immutability, temporary cleanup, M2TS/AC-3 proxy validation/cache reuse, VFR timestamps, and paths containing Unicode, spaces, and quotes.
- Developer visual checks covered automatic proxy playback, real-frame timestamp status, two adjacent clips, thumbnails, draft-to-retained transition, rename, earlier/later reorder, explicit trim update, I/O, J/K/L, Undo/Redo, and sequence preview in a 1280×900 window without a page scrollbar.

The macOS owner does not need to copy any Windows UI. Cross-platform review is only required if timestamp, overlap, export-mode, edit-list, or user-visible interaction semantics change.

## Remaining Windows release work

- Broad real-media, long-media, HDR/interlace, damaged-GOP, cancellation, and language-switch human checks
- Installer/portable packaging, dependency notices, artwork, signing, and clean-machine validation

References: `apps/windows/handover.md`, `apps/windows/HUMAN_CHECK.md`, `docs/PLATFORM_CONTRACT.md`, and `docs/milestones/WINDOWS_MULTI_RANGE_0.3.md`.
