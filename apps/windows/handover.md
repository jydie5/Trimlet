# Trimlet Windows implementation handover

- Prepared: 2026-08-16
- Repository: https://github.com/jydie5/Trimlet
- Baseline release: `v0.2.0-poc`
- Windows code status: not started
- Product status: macOS PoC 0.2 implemented; shared behavior is still evolving

## 1. Handover objective

Build a native Windows version of Trimlet with the same editing model and safety guarantees as the macOS version. Visual layout, platform APIs, and source code may differ. User-visible media behavior must remain aligned through the shared contracts and fixtures.

The first Windows milestone is not feature-complete video export. It is a small native application plus a tested platform-independent range/export-plan core that proves the repository and CI boundaries work.

## 2. Read these first

In this order:

1. `README.md` and `README.ja.md` — English/Japanese product and repository orientation.
2. `docs/REQUIREMENTS.md` — normative MUST/SHOULD requirements.
3. `docs/PLATFORM_CONTRACT.md` — shared terminology, timestamps, safety, and acceptance behavior.
4. `contracts/README.md` — versioning rules for machine-readable contracts.
5. `contracts/export-plan.schema.json` and `contracts/fixtures/export-plan-cases.json` — initial parity fixtures.
6. `contracts/error-codes.json` — stable cross-platform error identifiers.
7. `docs/ENCODING_PLAN.md` — what the current Accurate mode proves and what remains provisional.
8. `docs/legal/RELEASE_COMPLIANCE.md` and `THIRD_PARTY_NOTICES.md` — distribution boundaries.
9. `DONATIONS.md`, `DONATIONS.ja.md`, and `docs/development/project-sustainability*.md` — optional support and privacy policy.

Mac source is evidence of current behavior, not a Windows architecture specification.

## 3. Fixed product invariants

Do not change these in a Windows-only change:

- One source file and one IN/OUT range at a time.
- Source media is always read-only.
- Internal edit boundaries use source presentation timestamps, not floating-point frame numbers.
- A timestamp is represented as an integer value plus positive integer timescale.
- OUT is an exclusive end boundary for range duration calculations; `out > in` is required.
- Fast mode may move to keyframe-compatible boundaries and must explain that limitation.
- Accurate mode prioritizes selected timestamps and re-encodes when required.
- Output is written to an incomplete temporary path, validated, and only then finalized.
- Failure or cancellation must not leave a completed-looking output.
- Process arguments are passed as an argument array; never interpolate media paths into a shell command.
- Paths containing spaces, Japanese text, quotes, and emoji must work.
- Payment is optional and unlocks no feature.

If one of these must change, update the shared contract and fixtures in the same pull request and request macOS review.

## 4. Recommended Windows architecture

Use a native C# application with WinUI 3 and Windows App SDK. Pin the exact supported SDK and package versions in the first pull request rather than relying on a globally installed preview SDK.

Suggested solution layout:

```text
apps/windows/
  Trimlet.sln
  src/
    Trimlet.Windows/          WinUI views, commands, composition root
    Trimlet.Media/            timestamps, ranges, inspection/export plans
    Trimlet.Platform.Windows/ process, playback, filesystem, hardware adapters
  tests/
    Trimlet.Media.Tests/
    Trimlet.Contracts.Tests/
  packaging/
```

Keep `Trimlet.Media` independent from WinUI so range, timestamp, error mapping, and export planning can be tested without a window or GPU.

Recommended adapter boundaries:

| Boundary | Windows responsibility |
|---|---|
| Playback | Windows media APIs for directly supported preview media |
| Inspection | Managed `ffprobe` child process returning typed normalized metadata |
| Proxy | FFmpeg child process for preview-only compatibility media |
| Export | Pure export plan followed by a managed FFmpeg process |
| Hardware encode | Windows-specific capability selection behind the Accurate-mode contract |
| Filesystem | Safe temporary output, conflict handling, atomic finalization where supported |
| Progress | Parse FFmpeg `-progress` records into shared running/completed/failed/cancelled states |

Do not introduce Electron, Tauri, or a shared web UI without a new product decision.

### Localization and support

Create Windows resources from the first PR rather than embedding user-facing text in C# or XAML:

```text
apps/windows/src/Trimlet.Windows/Strings/
  en-US/Resources.resw
  ja-JP/Resources.resw
```

Use `x:Uid` or the Windows resource loader for visible text, accessible names, tooltips, dialogs, errors, and progress states. Japanese and English must describe the same behavior even when wording follows platform conventions.

The app may include a secondary `Support development` / `開発を応援` link to `https://buymeacoffee.com/jydie5`. It must never block editing or export, appear as an error, imply payment is required, or unlock a feature. Do not add analytics to measure link clicks.

## 5. First Windows pull request

The first PR should be deliberately small and contain:

1. A WinUI 3 application that opens an empty Trimlet window.
2. `Trimlet.Media` and test projects.
3. An integer `MediaTimestamp` value/timescale type with comparison that avoids floating-point conversion.
4. A `TrimRange` type with clamp and `out > in` validation.
5. Loading and validation of `contracts/error-codes.json`.
6. Tests that consume every case in `contracts/fixtures/export-plan-cases.json`.
7. Windows build/test commands added to `CONTRIBUTING.md`.
8. Windows workflow updated to restore, build, and test the solution.
9. English and Japanese `.resw` resources for the initial window, accessibility labels, and optional support link.
10. A decision entry recording exact Windows App SDK, .NET, minimum Windows, localization fallback, and packaging choices.

Acceptance for the first PR:

- It builds on a clean `windows-latest` GitHub runner.
- It does not require macOS, Swift, FFmpeg, or a media file.
- Shared contract fixtures pass on Windows.
- The macOS and shared-contract workflows remain green.
- Switching Windows display language between English and Japanese does not require code changes.

## 6. Suggested implementation sequence after the first PR

### Slice A — open and inspect

- File picker and drag/drop for MP4, MOV, M2TS, and MTS.
- External `ffprobe` discovery for development.
- Typed metadata normalization and shared error mapping.
- No FFmpeg binary bundled.

### Slice B — direct preview and navigation

- Direct playback for Windows-supported streams.
- Play/pause, scrub, one frame, ten frames, and five-second movement.
- Timestamp-based current position and range selection.
- Repeated play/pause stress test.

### Slice C — proxy preview

- Decide direct-preview suitability from inspected streams, not extension alone.
- Create preview-only H.264/AAC proxy with visible progress and cancellation.
- Retain the original source identity for final export.

### Slice D — Fast export

- Keyframe index and candidate range display.
- Stream copy where compatible, audio conversion where required.
- Temporary output, cancellation cleanup, and ffprobe validation.

### Slice E — Accurate export

- Timestamp-prioritized re-encode.
- Capability-driven Windows hardware encoder selection.
- Preserve or explicitly transform resolution, frame rate, interlace, HDR/color, aspect ratio, rotation, audio, and metadata.
- Do not copy the macOS PoC's fixed 12 Mbps setting as product policy.

## 7. FFmpeg and licensing boundary

For development, use a separately installed FFmpeg/ffprobe and record the detected version/configuration in test results. Do not commit or attach either executable.

The FFmpeg build used on the Mac developer machine contains GPL features including x264/x265 and is not an approved redistribution artifact. A future Windows bundle needs its own pinned build review, exact configure flags, dependency/source provenance, license texts, checksums, and corresponding-source handling.

Invoking FFmpeg as a process does not remove the obligations attached to a binary that Trimlet distributes. Codec patent questions are separate from open-source copyright licensing.

## 8. Shared test expectations

Generate synthetic media locally; do not commit personal or commercial video. Eventually cover:

- CFR 24, 30, 60, and 240 fps.
- 29.97 and 59.94 fps.
- Variable frame rate.
- Short and long GOP.
- H.264/HEVC MP4 or MOV.
- 1080i M2TS with AC-3.
- Multiple audio streams.
- Timestamp discontinuity or damaged opening GOP.
- 5 GB or larger input without memory scaling to file size.
- Paths with Japanese text, spaces, quotes, and emoji.

Binary output does not need to be byte-identical across platforms. Range behavior, selected codecs/container, validation outcome, and documented timing tolerance must align.

## 9. Collaboration rules

- Windows-only code stays under `apps/windows`.
- Changes to `contracts`, shared requirements, or platform behavior require both platform owners to review.
- Never repair a Windows limitation by silently weakening the shared requirement.
- Add a new decision entry rather than rewriting historical decisions.
- Pull requests must state media provenance and any dependency/license change.
- Keep the donation link optional and use only the repository's official URL.
- Keep English and Japanese strings in platform resource files and review both when behavior changes.

Initial ownership is `@jydie5`; replace or extend `/apps/windows/` in `.github/CODEOWNERS` when the Windows author's GitHub username is known.

## 10. Known questions for the Windows author

Record answers in `docs/DECISIONS.md` during implementation:

1. Exact .NET and Windows App SDK versions.
2. Minimum supported Windows 10/11 build.
3. Direct playback API and observed frame-step accuracy.
4. Development-time FFmpeg discovery policy.
5. Hardware encoder capability/probing strategy.
6. MSIX versus portable packaging for the first binary preview.
7. Code-signing plan.
8. Cache location and cleanup behavior.
9. Windows equivalents for reveal-in-Finder and platform shortcuts.
10. English/Japanese fallback language and translation review policy.

## 11. Handover completion checklist

- [x] Public repository and source baseline exist.
- [x] Shared requirements and JSON fixtures exist.
- [x] Windows workspace and CI entry exist.
- [x] Rights, FFmpeg, media, and donation boundaries are documented.
- [ ] Windows author GitHub username is added to CODEOWNERS.
- [ ] Windows author confirms this document was read.
- [ ] First Windows scaffold PR is opened.
- [ ] First Windows CI run is green.

The handover is ready to send when the recipient's GitHub username or contact destination is provided.
