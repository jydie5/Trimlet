# Make Trimlet your own

[App overview](README.md) · [日本語](DEVELOPING.ja.md)

For people adding a feature to their own fork, with or without an AI coding assistant. To use the app without building it, read the [user guide](docs/user-guide.md).

## Start with a bounded change

1. Fork this repository and clone your fork.
2. Create a branch and choose Windows, Mac or both.
3. Describe the user-visible result and how you will check it.
4. Build and test the existing app before changing it.

Personal modifications need no upstream PR or approval. Keep the MIT notice and respect dependency licenses when redistributing. To contribute upstream, read [Contributing](CONTRIBUTING.md).

## Code map

| Area | Location |
|---|---|
| Windows UI and interaction | `apps/windows/src/Trimlet.Windows/` |
| Windows edit model and export plans | `apps/windows/src/Trimlet.Media/` |
| Windows files and media tools | `apps/windows/src/Trimlet.Platform.Windows/` |
| Mac UI and interaction | `apps/macos/Sources/Trimlet/` |
| Mac core | `apps/macos/Sources/TrimletCore/` |
| Shared semantics and file format | `contracts/`, [platform contract](docs/PLATFORM_CONTRACT.md) |
| UI and copy decisions | [Product design](docs/PRODUCT_DESIGN.md) |

Trimlet collects ranges from one video. Preserve the source, exclusive OUT semantics, existing project compatibility and Fast/Accurate meanings. Native implementations need not share code or identical layouts.

## Run on Windows

Use a Windows development environment, .NET SDK **10.0.400** (`apps/windows/global.json`), and separately installed FFmpeg/ffprobe. Unlike the downloadable app, source builds require the SDK.

From the repository root in PowerShell:

```powershell
.\apps\windows\run-human-check.ps1
```

This validates contracts, tests and synthetic exports, then builds and launches the developer app. [Individual build commands and implementation notes](apps/windows/README.md).

## Run on Mac

Use macOS 14+, a Swift tools 6.1-compatible toolchain and separately installed FFmpeg/ffprobe. The recorded test environment is Apple silicon; see [environment notes](docs/ENVIRONMENT.md) for tool locations.

```bash
swift build --package-path apps/macos
swift run --package-path apps/macos TrimletCoreChecks
swift run --package-path apps/macos TrimletIntegrationChecks
scripts/validate-contracts.sh
```

Run the root `run-poc.command` to build and open the current source as `dist/Trimlet.app`. Despite the historical filename, it builds current source. Handle unsaved work in a running Trimlet instance first.

## Example task for an AI coding assistant

> Add “my desired feature” to this Trimlet fork, targeting Windows only.
> Read DEVELOPING.md, docs/PRODUCT_DESIGN.md and the relevant code first. Explain the planned changes and acceptance checks.
> Preserve source-video safety, existing project compatibility and the other platform's behavior.
> If a shared contract must change, explain why and its compatibility impact before doing so.
> Add and run tests, and leave the app ready to launch.
> Summarize the changes, actual tests, manual checks I should perform and anything unverified.
> Do not publish commits or create a release until I request that.

## Before calling it done

- Run affected tests and shared-contract validation.
- Check the new interaction and existing open, mark, save and export flows in the real app.
- Update contracts, fixtures and the other platform's handover for shared behavior changes.
- Separate verified results from pending checks. Do not infer other-platform or clean-machine acceptance.
- Do not commit personal media, credentials, FFmpeg executables or generated builds.

[Windows manual checks](apps/windows/HUMAN_CHECK.md) · [Mac manual checks](docs/HUMAN_CHECK.md) · [Design, verification and maintainer index](docs/README.md)

Only people producing screenshots need the [demo-footage recipe](docs/WINDOWS_DEMO.md). It is not part of installation or normal feature development.
