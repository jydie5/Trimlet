# Windows multi-range parity 0.3

- Date: 2026-08-28
- Baseline: macOS `v0.3.0-beta.1`
- State: implemented and developer-verified; Windows user human check pending

## Delivered

- Immutable edit-list model with stable clip ID/name, non-overlap validation, move/update/delete, and undo/redo snapshots.
- Shared edit-list fixture validation on Windows.
- Ordered multi-range Fast and Accurate planning, per-segment temporary outputs, concat, weighted progress, cancellation cleanup, and final validation.
- WinUI editing sequence with explicit draft and trim states, thumbnails, rename, delete, reorder, earlier/later controls, clip preview, and continuous sequence preview.
- Visible I/O shortcuts, signed 1x/2x/4x/8x J/K/L shuttle state, coalesced scrub seeks, exact release seek, and non-modal keyframe inspection.
- English and Japanese resources for the added UI.

## Developer evidence

- Release WinUI build: zero warnings and zero errors.
- Unit and shared-contract suite: 21 tests passed in Release configuration.
- Generated-media integration: single-range Fast/Accurate plus reordered three-segment Fast/Accurate output passed, including duration/order validation, source immutability, partial cleanup, and special-character paths.
- Visual operation check: two adjacent clips added with thumbnails, no card overlap or page scrollbar at 1280×900, Undo/Redo restored sequence state, sequence preview crossed the clip boundary, and J/K/L state was visible.

Shared PowerShell contract validation also passed. CI status belongs in the pull request; the remaining user-facing manual gate is `apps/windows/HUMAN_CHECK.md`.

## Not claimed

This milestone does not claim automatic preview-proxy parity, source-PTS frame stepping for VFR media, distributable Windows binaries, code signing, or completion of the broad real-media matrix.
