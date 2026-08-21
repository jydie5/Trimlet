# Trimlet for Windows — Early Access

## Status

Version `v0.3.0-early-access.1` is a source-only preview. It opens as an unpackaged WinUI 3 application, accepts supported media through a picker or drag and drop, provides Windows-native playback and seeking, inspects the source with `ffprobe`, records one IN/OUT range, and writes validated MP4 output through FFmpeg.

Fast mode uses stream copy and reports its keyframe-expanded candidate. Accurate mode preserves the selected timestamps and converts to H.264/AAC with a working encoder discovered on the current Windows machine. Exports are written to a temporary file, checked with `ffprobe`, and only then moved to their final name.

Start with [the human-check guide](HUMAN_CHECK.md). Maintainers should also read [the Windows implementation handover](handover.md).

## Run Early Access

From the repository root in PowerShell:

```powershell
.\apps\windows\run-human-check.ps1
```

The script validates shared contracts, runs unit and integration checks with generated media, builds the app, and launches it. It does not download or bundle FFmpeg.

## Current parity and limitations

The core user workflow matches the macOS PoC: open one local video, navigate, set one IN/OUT range, preview it, and export in Fast or Accurate mode without modifying the source. Windows additionally exposes an audio-stream picker.

This Early Access is not complete platform parity:

- Windows-native playback has no automatic proxy fallback yet; the macOS PoC can generate a preview proxy for incompatible media.
- Frame movement uses the inspected nominal rational frame rate rather than presentation timestamps for variable-frame-rate media.
- There is no installer, MSIX, code signature, or supported prebuilt executable.
- M2TS/MTS preview depends on codecs installed in Windows, although FFmpeg export may still work.

## Recommended native stack

- C# and .NET
- WinUI 3 with Windows App SDK
- Windows-native playback APIs for preview
- `ffprobe` and FFmpeg as managed child processes for media inspection and export parity
- `.resw` resources for English and Japanese user-facing text from the first change

Pin exact SDK and package versions in the first Windows implementation change. Do not silently depend on a developer-machine FFmpeg build in distributable artifacts.

## Implemented Windows slice

1. WinUI 3 application that opens without requiring the macOS tree.
2. Platform-independent timestamp, rational frame-rate, range, keyframe, progress, and export-plan core with tests.
3. `ffprobe` source inspection and keyframe indexing.
4. Fast and Accurate FFmpeg plans with argument-safe process launch, progress, cancellation, temporary output, validation, and diagnostics.
5. Canonical `contracts/error-codes.json` loader and validation, with both shared fixtures exercised by Windows tests.
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
