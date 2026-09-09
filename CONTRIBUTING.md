# Contributing to Trimlet

Trimlet keeps native macOS and Windows implementations in one repository while sharing behavioral contracts.

このページは本家へ変更を提案する方向けです。自分用の改造にPRは不要です。
[開発・AIでの改造](DEVELOPING.ja.md) / [Start developing](DEVELOPING.md).
不具合や機能要望は日本語・英語で受け付けます。コードを書く必要はありません。

## Before contributing

- Do not submit code or media you do not have the right to contribute.
- Do not commit generated videos, application bundles, FFmpeg binaries, secrets, or personal file paths.
- Contributions use the repository's MIT license unless an explicit written agreement says otherwise. Bundled dependencies retain their own terms.

## Change scope

- macOS implementation: `apps/macos/`
- Windows implementation: `apps/windows/`
- shared behavior: `contracts/`, `docs/REQUIREMENTS.md`, and `docs/PLATFORM_CONTRACT.md`

Visible behavior changes require shared-contract review. Platform implementation details do not need to be artificially shared.

## Local checks

macOS:

```bash
swift build --package-path apps/macos
swift run --package-path apps/macos TrimletCoreChecks
scripts/validate-contracts.sh
```

Windows:

```powershell
./scripts/validate-contracts.ps1
dotnet restore apps/windows/Trimlet.sln --configfile apps/windows/NuGet.Config
dotnet restore apps/windows/src/Trimlet.Windows/Trimlet.Windows.csproj --runtime win-x64 --configfile apps/windows/NuGet.Config
dotnet restore apps/windows/checks/Trimlet.IntegrationChecks/Trimlet.IntegrationChecks.csproj --configfile apps/windows/NuGet.Config
dotnet test apps/windows/Trimlet.sln --configuration Release --no-restore
dotnet build apps/windows/src/Trimlet.Windows/Trimlet.Windows.csproj --configuration Release --runtime win-x64 --no-restore
dotnet run --project apps/windows/checks/Trimlet.IntegrationChecks/Trimlet.IntegrationChecks.csproj --configuration Release --no-restore -- --require-tools
./apps/windows/run-human-check.ps1
```

## Pull requests

Explain the user-visible effect, affected platform, test evidence, media provenance, and any dependency or license change. Do not attach private media to an issue or pull request.

AI-assisted contributions follow the same review standard: understand the changes,
keep the diff focused, and report which checks actually ran. Include manual
acceptance steps and clearly mark checks requiring another OS or human input.
An AI-generated claim that tests passed is not a substitute for running them.

Public-facing documentation follows the [two-audience documentation policy](docs/development/documentation-policy.md).
