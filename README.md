# Trimlet

必要なところだけ、すばやく正確に。

Trimlet is a lightweight, frame-accurate video trimming application with separate native implementations for macOS and Windows.

The macOS proof of concept is implemented in SwiftUI. Windows development follows the same product and media-processing contracts while remaining free to use Windows-native APIs and C#.

## Product goal

Trimlet opens large video files without loading the whole file into memory, lets the user mark one IN/OUT range, and exports the selected range as MP4.

It intentionally focuses on one workflow:

1. Open or drop a video.
2. Find the desired range quickly.
3. Mark IN and OUT precisely.
4. Export in Fast or Accurate mode.

Priority inputs are MP4, MOV, M2TS, and MTS.

## Repository status

- macOS: native PoC 0.2, ready for the next human evaluation.
- Windows: implementation workspace and shared contracts are ready for a Windows contributor; application code has not yet been added.
- Public source release: ready under the MIT License after automated checks pass.

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
- Swift toolchain compatible with Swift tools 6.2
- Separately installed `ffmpeg` and `ffprobe` in `/opt/homebrew/bin` or `/usr/local/bin`

Double-click `run-poc.command` to build an ad-hoc local application at `dist/Trimlet.app` and open it. Nothing is installed globally or uploaded.

Core checks can be run with:

```bash
swift run --package-path apps/macos TrimletCoreChecks
```

Generated media and `dist/` are local-only and ignored by Git.

## Support development

Trimlet is free, MIT-licensed software. If it is useful, you may **[voluntarily support continued development on Buy Me a Coffee](https://buymeacoffee.com/jydie5)**.

Support is optional. Payment does not unlock features, change the license, or give paying users priority. Stars, sharing, reproducible bug reports, testing on different machines, and code or documentation improvements are also welcome. See [Supporting Trimlet](DONATIONS.md).

## Documentation

- [Product requirements](docs/REQUIREMENTS.md)
- [Technical decisions](docs/DECISIONS.md)
- [Open questions](docs/OPEN_QUESTIONS.md)
- [Mac/Windows platform contract](docs/PLATFORM_CONTRACT.md)
- [Windows implementation handoff](apps/windows/README.md)
- [Mac PoC scope](docs/POC.md)
- [Human-check guide](docs/HUMAN_CHECK.md)
- [Verified environment](docs/ENVIRONMENT.md)
- [PoC verification record](docs/VERIFICATION.md)
- [Accurate export and FFmpeg plan](docs/ENCODING_PLAN.md)
- [Release compliance checklist](docs/legal/RELEASE_COMPLIANCE.md)
- [Name/trademark search record](docs/legal/TRADEMARK_SEARCH_2026-08-16.md)
- [Project license recommendation](docs/legal/LICENSE_DECISION.md)
- [Development backlog](docs/BACKLOG.md)

## Privacy and safety

Media processing is local. Trimlet has no account, analytics, telemetry, or upload feature. Source media is treated as read-only, and exports are finalized only after validation.

## License

Trimlet source code and documentation are available under the [MIT License](LICENSE). The copyright notice uses the collective name `Trimlet contributors`; no personal attribution is required beyond preserving the MIT notice in copies or substantial portions.

FFmpeg is a separate project with its own license conditions; see [Third-party notices](THIRD_PARTY_NOTICES.md).
