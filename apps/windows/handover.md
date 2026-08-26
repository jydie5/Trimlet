# Trimlet Windows maintainer handover

- Prepared: 2026-08-21
- Release: `v0.3.0-early-access.1`
- Repository: https://github.com/jydie5/Trimlet
- Distribution: source only; no installer, signed executable, or bundled FFmpeg

## Current implementation

The first native Windows workflow is implemented in C# and WinUI 3. A user can open or drop one local video, play and seek it, move by frames or seconds, set one IN/OUT range, select an audio stream, preview the range, and export a validated MP4 in Fast or Accurate mode.

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

- One source file and one IN/OUT range at a time.
- Source media is read-only.
- OUT is an exclusive boundary and must be greater than IN.
- Fast mode may expand to compatible keyframes and must disclose that behavior.
- Accurate mode prioritizes the selected timestamps and re-encodes when required.
- Export uses a partial file, validates it with `ffprobe`, then finalizes it.
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

## Next implementation order

1. Match the 2026-08-26 interaction contract: distinct uncommitted-range fill plus dashed boundary, blue retained ranges, and non-modal keyframe inspection state.
2. Add J/K/L shuttle levels with visible direction/speed, plus responsive slider scrubbing followed by an exact final seek. Use the Windows-native playback rate when supported and a bounded seek fallback otherwise.
3. Add preview suitability detection and a cancellable proxy cache without changing source identity.
4. Move VFR navigation and boundaries to source PTS end to end.
5. Expand generated and real-machine media coverage.
6. Select a Windows distribution format and complete the binary release gate in `docs/legal/RELEASE_COMPLIANCE.md`.
7. Add an original application icon and code signing before publishing a binary.

The shared acceptance behavior for items 1–2 is normative in `docs/PLATFORM_CONTRACT.md`. The Mac implementation is only a behavioral reference; do not port SwiftUI or AVPlayer code into Windows.

## Collaboration rules

- Keep Windows-only code under `apps/windows`.
- Keep native UI and playback code separate from macOS.
- Add a decision entry rather than rewriting accepted historical decisions.
- Update English and Japanese resources together.
- Pull requests must disclose media provenance and dependency or license changes.
- Diagnostics must keep media paths redacted.

The cross-platform follow-up is recorded in [`../macos/WINDOWS_EARLY_ACCESS_HANDOVER.md`](../macos/WINDOWS_EARLY_ACCESS_HANDOVER.md).
