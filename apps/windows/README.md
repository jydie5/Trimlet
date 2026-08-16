# Trimlet for Windows — implementation handoff

## Status

The Windows implementation has not started in code. This directory is its ownership boundary inside the Trimlet monorepo. The first Windows contributor should create the solution here without changing the macOS package.

Start with [the Windows implementation handover](handover.md).

## Recommended native stack

- C# and .NET
- WinUI 3 with Windows App SDK
- Windows-native playback APIs for preview
- `ffprobe` and FFmpeg as managed child processes for media inspection and export parity
- `.resw` resources for English and Japanese user-facing text from the first change

Pin exact SDK and package versions in the first Windows implementation change. Do not silently depend on a developer-machine FFmpeg build in distributable artifacts.

## Required first slice

1. Create a WinUI application that opens without requiring the macOS tree.
2. Add a test project for platform-independent timestamp and range behavior.
3. Read `contracts/error-codes.json` and use the canonical error identifiers.
4. Implement the export-plan contract before connecting a real FFmpeg process.
5. Run the shared fixtures on Windows CI.
6. Record Windows-specific API and packaging choices in `docs/DECISIONS.md`.

## Rules for parity

The authoritative shared behavior is in:

- `docs/REQUIREMENTS.md`
- `docs/PLATFORM_CONTRACT.md`
- `contracts/README.md`
- `contracts/fixtures/export-plan-cases.json`

Windows may use different UI controls, playback APIs, hardware encoders, and packaging. It must preserve timestamp semantics, source safety, Fast/Accurate meanings, progress states, cancellation behavior, and output validation.

When a shared contract needs to change, update the contract and fixtures in the same pull request and request review from both platform owners.

## Expected future layout

```text
apps/windows/
  Trimlet.sln
  src/Trimlet.Windows/
  src/Trimlet.Media/
  tests/Trimlet.Media.Tests/
  packaging/
```

Do not copy Swift types into C#. Implement the same externally visible contract using idiomatic Windows code.
