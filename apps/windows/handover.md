# Trimlet Windows maintainer handover

- Prepared: 2026-08-28
- Published Windows release: `v0.3.0-early-access.1`
- Current source state: multi-range parity candidate for Mac `v0.3.0-beta.1`; Windows human check pending
- Repository: https://github.com/jydie5/Trimlet
- Distribution: source only; no installer, signed executable, or bundled FFmpeg

## Current implementation

The native Windows workflow is implemented in C# and WinUI 3. A user can open or drop one local video, play and seek it, move by frames or seconds, collect multiple non-overlapping ranges in an ordered editing sequence, and export one validated MP4 in Fast or Accurate mode.

The Mac Beta handover has been adopted in the Windows source: draft and retained ranges are distinct, clip cards have stable editable names and FFmpeg-generated thumbnails, card selection is separate from explicit trim editing, reorder/delete/undo/redo are available, sequence preview skips source gaps, and J/K/L plus visible I/O shortcuts follow the shared interaction model. The audio picker appears only for multi-audio sources.

The solution is split into:

```text
apps/windows/
  src/Trimlet.Windows/          WinUI application and localization
  src/Trimlet.Media/            timestamps, ranges, inspection, and export plans
  src/Trimlet.Platform.Windows/ Windows process, filesystem, and FFmpeg adapters
  tests/                        unit and shared-contract tests
  checks/                       generated-media FFmpeg integration checks
```

Run the complete local gate from the repository root:

```powershell
.\apps\windows\run-human-check.ps1
```

## Product invariants

- One source file and multiple non-overlapping retained IN/OUT ranges in explicit output order.
- Source media is read-only.
- OUT is an exclusive boundary and must be greater than IN.
- Fast mode may expand to compatible keyframes and must disclose that behavior.
- Accurate mode prioritizes the selected timestamps and re-encodes when required.
- Multi-range export creates per-operation temporary segments, concatenates them in edit-list order, validates the combined partial output with `ffprobe`, then finalizes it.
- Cancellation or failure must not leave completed-looking output.
- Media paths are process arguments, never interpolated shell text.
- Payments are optional and unlock no feature.

If one of these changes, update `docs/PLATFORM_CONTRACT.md`, the JSON contracts or fixtures when applicable, and request both platform owners to review the same change.

## Toolchain and dependencies

- .NET SDK 10.0.400, pinned by `global.json`
- Windows App SDK 2.4.0
- Target SDK 26100; declared minimum Windows build 17763
- English fallback and Japanese `.resw` resources
- Separately installed `ffmpeg` and `ffprobe`

FFmpeg discovery checks `TRIMLET_FFMPEG` / `TRIMLET_FFPROBE`, the application directory, and `PATH`. Accurate mode probes H.264 encoder candidates with an actual encode instead of trusting only the encoder list. Do not commit or attach developer-machine FFmpeg executables.

## Known Early Access gaps

1. No automatic preview proxy is generated when Windows-native playback cannot decode the source.
2. Frame movement uses nominal rational frame rate, not source presentation timestamps for variable-frame-rate media.
3. The app is an unpackaged, framework-dependent developer build.
4. MSIX/portable packaging, original release artwork, signing, and clean-machine binary verification are not complete.
5. The large-media, damaged-GOP, HDR, and full language-switch matrices need broader real-machine coverage.

## macOS 0.3 interaction delta adopted

The macOS 0.3 work treats trimming as an editing sequence rather than a single disposable range. The interaction checkpoint was accepted on 2026-08-28, recorded in `docs/PLATFORM_CONTRACT.md`, and implemented in the current Windows source:

- Keep an uncommitted IN/OUT range visually distinct from retained clips. The Mac reference uses a translucent purple fill with a dashed boundary for the draft, blue for retained clips, green for IN, and red for OUT. Windows may use native styling, but draft versus retained state must not rely on color alone.
- Add multiple retained subclips with stable identity, editable names, representative thumbnails, source IN–OUT time, drag reorder, trim, delete, undo/redo, sequence preview, and combined export.
- Expose `J Reverse`, `K Stop`, and `L Forward` as meaningful controls. Repeated J/L presses select the bounded 1x, 2x, 4x, and 8x levels; the current direction and speed remain visible.
- Expose the existing `I` and `O` commands on the Set IN and Set OUT buttons with keycap-like hints. A user must be able to discover the shortcut without opening documentation.
- Keep continuous slider or precision-touchpad scrubbing responsive, then perform an exact seek when the gesture ends.
- Keep keyframe inspection non-modal after playable media is visible. Proxy generation and export remain cancellable operations with visible progress.

Do not copy Mac colors or SwiftUI layout mechanically. Match the state model, discoverability, keyboard semantics, and acceptance behavior using WinUI conventions and English/Japanese resources.

Developer verification covers a two-clip add flow, thumbnails, distinct timeline states, keyboard I/O, J/K/L state changes and reverse-seek fallback, Undo/Redo, and sequence preview. Generated-media integration checks cover reordered three-segment Fast and Accurate exports. The remaining gate is the user-run checklist in `HUMAN_CHECK.md` on representative media.

## Next implementation order

1. Complete the Windows human-check matrix for multi-audio, non-contiguous reordered clips, cancellation, long media, damaged GOPs, HDR/interlace, and both UI languages.
2. Add preview suitability detection and a cancellable proxy cache without changing source identity.
3. Move VFR navigation and boundaries to source PTS end to end.
4. Select a Windows distribution format and complete the binary release gate in `docs/legal/RELEASE_COMPLIANCE.md`.
5. Add original application artwork and code signing before publishing a binary.

The shared interaction behavior remains normative in `docs/PLATFORM_CONTRACT.md`. The Mac implementation is only a behavioral reference; do not port SwiftUI or AVPlayer code into Windows.

## Collaboration rules

- Keep Windows-only code under `apps/windows`.
- Keep native UI and playback code separate from macOS.
- Add a decision entry rather than rewriting accepted historical decisions.
- Update English and Japanese resources together.
- Pull requests must disclose media provenance and dependency or license changes.
- Diagnostics must keep media paths redacted.

The original Early Access handover remains in [`../macos/WINDOWS_EARLY_ACCESS_HANDOVER.md`](../macos/WINDOWS_EARLY_ACCESS_HANDOVER.md). The current parity return is [`../macos/WINDOWS_MULTI_RANGE_HANDOVER.md`](../macos/WINDOWS_MULTI_RANGE_HANDOVER.md).
