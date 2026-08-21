# Trimlet

[English](README.md) | [日本語](README.ja.md)

Only what you need, quickly and precisely.

Trimlet is a lightweight, frame-accurate video trimming application with separate native implementations for macOS and Windows.

The macOS proof of concept is implemented in SwiftUI. A native C#/WinUI 3 Windows Early Access implementation now follows the same product and media-processing contracts.

## Product goal

Trimlet opens large video files without loading the whole file into memory, lets the user mark one IN/OUT range, and exports the selected range as MP4.

It intentionally focuses on one workflow:

1. Open or drop a video.
2. Find the desired range quickly.
3. Mark IN and OUT precisely.
4. Export in Fast or Accurate mode.

Priority inputs are MP4, MOV, M2TS, and MTS.

## Repository status

- macOS: native PoC 0.2 with direct preview, automatic preview proxies, range selection, and Fast/Accurate export.
- Windows: source-only Early Access with native preview, range selection, audio-stream selection, and validated Fast/Accurate export.
- Parity: the primary open → select IN/OUT → export workflow is aligned. Windows automatic preview proxies and source-PTS stepping for variable-frame-rate media remain open.
- Public source releases are published under the MIT License.

Latest macOS PoC source release: [v0.2.1-poc](https://github.com/jydie5/Trimlet/releases/tag/v0.2.1-poc)

Windows Early Access: [v0.3.0-early-access.1](https://github.com/jydie5/Trimlet/releases/tag/v0.3.0-early-access.1) (source only; no installer or prebuilt executable)

This repository does **not** contain or redistribute FFmpeg, ffprobe, sample videos, or generated application bundles. The current PoC uses a separately installed FFmpeg executable.

## Repository layout

```text
apps/macos/       SwiftUI and AVFoundation implementation
apps/windows/     Windows implementation workspace
contracts/        Platform-neutral data and behavior contracts
docs/             Product, architecture, test, and legal records
scripts/          Local build and validation helpers
.github/          Platform-specific CI and contribution templates
```

The native UI and playback layers are intentionally not shared. Product terminology, timestamp rules, export modes, error categories, fixtures, and acceptance behavior are shared.

See [Repository structure](docs/architecture/REPOSITORY_STRUCTURE.md) and the [platform contract](docs/PLATFORM_CONTRACT.md).

## Try the macOS PoC

Prerequisites:

- Apple silicon Mac
- Swift toolchain compatible with Swift tools 6.1
- Separately installed `ffmpeg` and `ffprobe` in `/opt/homebrew/bin` or `/usr/local/bin`

Double-click `run-poc.command` to build an ad-hoc local application at `dist/Trimlet.app` and open it. Nothing is installed globally or uploaded.

Core checks can be run with:

```bash
swift run --package-path apps/macos TrimletCoreChecks
```

Generated media and `dist/` are local-only and ignored by Git.

## Try Windows Early Access

Prerequisites:

- Windows 10 build 17763 or later
- .NET SDK 10.0.400
- Separately installed `ffmpeg` and `ffprobe` on `PATH`, in `TRIMLET_FFMPEG` / `TRIMLET_FFPROBE`, or beside the built app

From PowerShell:

```powershell
git clone https://github.com/jydie5/Trimlet.git
Set-Location .\Trimlet
.\apps\windows\run-human-check.ps1
```

This validates contracts, tests, and synthetic exports before launching the unpackaged developer build. See the [Windows Early Access guide](apps/windows/README.md) and [human-check steps](apps/windows/HUMAN_CHECK.md).

## Support development

Trimlet is free, MIT-licensed software. If it is useful, you may **[voluntarily support continued development on Buy Me a Coffee](https://buymeacoffee.com/jydie5)**.

Support helps with code signing, Windows/macOS hardware validation, build services, and development AI/API costs. It is optional: payment does not unlock features, change the license, or give paying users priority.

You can also help at no cost by starring or sharing the repository, reporting reproducible bugs, testing on different machines, or improving code and documentation. See [Supporting Trimlet](DONATIONS.md) and [how project reach and support are measured](docs/development/project-sustainability.md). Trust only funding links published in this repository.

## Documentation

- [Product requirements](docs/REQUIREMENTS.md)
- [Technical decisions](docs/DECISIONS.md)
- [Open questions](docs/OPEN_QUESTIONS.md)
- [Mac/Windows platform contract](docs/PLATFORM_CONTRACT.md)
- [Product and interface design principles](docs/PRODUCT_DESIGN.md)
- [Windows Early Access guide](apps/windows/README.md)
- [Windows maintainer handover](apps/windows/handover.md)
- [Windows-to-macOS owner handover](apps/macos/WINDOWS_EARLY_ACCESS_HANDOVER.md)
- [Mac PoC scope](docs/POC.md)
- [Human-check guide](docs/HUMAN_CHECK.md)
- [Verified environment](docs/ENVIRONMENT.md)
- [PoC verification record](docs/VERIFICATION.md)
- [Accurate export and FFmpeg plan](docs/ENCODING_PLAN.md)
- [Release compliance checklist](docs/legal/RELEASE_COMPLIANCE.md)
- [Name/trademark search record](docs/legal/TRADEMARK_SEARCH_2026-08-16.md)
- [Project license recommendation](docs/legal/LICENSE_DECISION.md)
- [Project sustainability and reach](docs/development/project-sustainability.md)
- [Development backlog](docs/BACKLOG.md)

## Privacy and safety

Media processing is local. Trimlet has no account, analytics, telemetry, or upload feature. Source media is treated as read-only, and exports are finalized only after validation.

## License

Trimlet source code and documentation are available under the [MIT License](LICENSE). The copyright notice uses the collective name `Trimlet contributors`; no personal attribution is required beyond preserving the MIT notice in copies or substantial portions.

FFmpeg is a separate project with its own license conditions; see [Third-party notices](THIRD_PARTY_NOTICES.md).
