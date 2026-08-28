# Trimlet for Windows — Early Access

## Status

The Windows source tree implements the macOS `v0.3.0-beta.1` interaction contract, and the feature-focused human check was accepted on 2026-08-28. It remains an unpackaged, source-only Early Access build until distribution work is complete.

The app accepts supported media through a picker or drag and drop, provides Windows-native playback and seeking, inspects the source with `ffprobe`, and builds an ordered editing sequence from multiple non-overlapping IN/OUT ranges. Retained clips have stable editable names, representative thumbnails, explicit trim editing, reordering, deletion, undo/redo, and continuous sequence preview. M2TS/MTS sources and direct-playback failures use a validated, cancellable preview proxy while export continues to read the original source.

Fast mode plans a keyframe-compatible candidate for every retained clip, stream-copies each segment, and concatenates the ordered results without video re-encoding. Accurate mode preserves the requested timestamps, re-encodes each segment to H.264/AAC with a working encoder discovered on the current machine, and concatenates them. Final output is validated with `ffprobe` before it receives a completed-looking name.

Start with [the human-check guide](HUMAN_CHECK.md). Maintainers should also read [the Windows implementation handover](handover.md).

## Run Early Access

From the repository root in PowerShell:

```powershell
.\apps\windows\run-human-check.ps1
```

The script validates shared contracts, runs unit and integration checks with generated media, builds the app, and launches it. It does not download or bundle FFmpeg.

## Current parity and limitations

The implemented interaction contract matches the macOS Beta for one-source multi-range editing: a visually distinct draft, retained clips, editing-sequence manipulation, J/K/L shuttle levels, discoverable I/O shortcuts, coalesced scrubbing, non-modal keyframe analysis, sequence preview, and combined Fast/Accurate export. Windows uses WinUI-native controls and only shows the audio-stream picker when the source contains multiple streams.

The current source has caught up with the accepted macOS Beta interaction and preview behavior. Windows builds a source presentation-timestamp index in the background and uses it for frame movement when ready; the inspected nominal rate remains a responsive fallback while analysis is running.

The remaining Early Access limitations are release and coverage gates rather than known Mac-baseline feature gaps:

- There is no installer, MSIX, code signature, or supported prebuilt executable.
- Long, damaged-GOP, HDR, interlaced, and cancellation cases still need broader representative-media checks on Windows machines.

## Recommended native stack

- C# and .NET
- WinUI 3 with Windows App SDK
- Windows-native playback APIs for preview
- `ffprobe` and FFmpeg as managed child processes for media inspection and export parity
- `.resw` resources for English and Japanese user-facing text from the first change

Pin exact SDK and package versions in the first Windows implementation change. Do not silently depend on a developer-machine FFmpeg build in distributable artifacts.

## Implemented Windows slice

1. WinUI 3 application that opens without requiring the macOS tree.
2. Platform-independent timestamp, rational frame-rate, edit-list, keyframe, progress, and single-/multi-range export-plan core with tests.
3. `ffprobe` source inspection and keyframe indexing.
4. Ordered Fast and Accurate FFmpeg segment/concat plans with argument-safe process launch, weighted progress, cancellation, temporary output, validation, and diagnostics.
5. Canonical error-code and edit-list contract validation, including reordered valid segments and overlapping invalid segments from shared fixtures.
6. English and Japanese `.resw` resources.
7. Repeatable unit, integration, build, launch, and human-check instructions.

## Toolchain discovery

The developer build does not bundle FFmpeg. Put `ffmpeg` and `ffprobe` on `PATH`, set `TRIMLET_FFMPEG` and `TRIMLET_FFPROBE` to their full paths, or place both executables beside the built app. The application verifies the tools before export and probes H.264 encoders for actual usability rather than trusting the encoder list alone.

Run [the Windows human check](HUMAN_CHECK.md) when evaluating this slice.

## Rules for parity

The authoritative shared behavior is in:

- `docs/REQUIREMENTS.md`
- `docs/PLATFORM_CONTRACT.md`
- `contracts/README.md`
- `contracts/fixtures/export-plan-cases.json`

Windows may use different UI controls, playback APIs, hardware encoders, and packaging. It must preserve timestamp semantics, source safety, Fast/Accurate meanings, progress states, cancellation behavior, and output validation.

When a shared contract needs to change, update the contract and fixtures in the same pull request and request review from both platform owners.

## Current layout

```text
apps/windows/
  Trimlet.sln
  src/Trimlet.Windows/
  src/Trimlet.Media/
  src/Trimlet.Platform.Windows/
  tests/Trimlet.Media.Tests/
  tests/Trimlet.Contracts.Tests/
  checks/Trimlet.IntegrationChecks/
  packaging/
```

Do not copy Swift types into C#. Implement the same externally visible contract using idiomatic Windows code.
