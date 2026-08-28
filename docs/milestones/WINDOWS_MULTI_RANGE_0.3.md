# Windows multi-range parity 0.3

- Date: 2026-08-28
- Baseline: macOS `v0.3.0-beta.1`
- State: implemented, developer-verified, and feature-focused human check accepted on 2026-08-28

## Delivered

- Immutable edit-list model with stable clip ID/name, non-overlap validation, move/update/delete, and undo/redo snapshots.
- Shared edit-list fixture validation on Windows.
- Ordered multi-range Fast and Accurate planning, per-segment temporary outputs, concat, weighted progress, cancellation cleanup, and final validation.
- WinUI editing sequence with explicit draft and trim states, thumbnails, rename, delete, reorder, earlier/later controls, clip preview, and continuous sequence preview.
- Visible I/O shortcuts, signed 1x/2x/4x/8x J/K/L shuttle state, coalesced scrub seeks, exact release seek, and non-modal keyframe inspection.
- Validated, cancellable preview proxies for M2TS/MTS and direct-playback failures, with source-identity-preserving cache keys and atomic finalization.
- Non-modal source presentation-timestamp indexing with actual-frame stepping after the index is ready.
- English and Japanese resources for the added UI.

## Developer evidence

- Release WinUI build: zero warnings and zero errors.
- Unit and shared-contract suite: 30 tests passed in Release configuration.
- Generated-media integration: single-range Fast/Accurate plus reordered three-segment Fast/Accurate output passed, including sampled output color order, selected non-default audio, duration validation, source immutability, partial cleanup, and special-character paths. M2TS/AC-3 proxy validation/cache reuse and irregular VFR presentation timestamps also passed.
- Visual operation check: automatic M2TS proxy playback, VFR actual-frame status, two adjacent clips with thumbnails, no card overlap or page scrollbar at 1280×900, rename persistence, earlier/later reorder, explicit trim update, Undo/Redo, sequence preview, and visible J/K/L state.

Shared PowerShell contract validation and GitHub CI also passed. The user accepted the feature-focused human check on 2026-08-28. `apps/windows/HUMAN_CHECK.md` remains the repeatable regression and representative-media checklist.

## Not claimed

This milestone does not claim distributable Windows binaries, code signing, clean-machine validation, or completion of the broad real-media matrix. Those are release and distribution gates, not known gaps against the accepted Mac interaction baseline.
