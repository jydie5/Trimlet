# Contributing to Trimlet

Trimlet keeps native macOS and Windows implementations in one repository while sharing behavioral contracts.

## Before contributing

- Do not submit code or media you do not have the right to contribute.
- Do not commit generated videos, application bundles, FFmpeg binaries, secrets, or personal file paths.
- Until the root project license is selected, outside contributions must not be solicited or merged.
- Once a license is present, contributions are made under that repository license unless an explicit written agreement says otherwise.

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
```

Windows build and test commands must be added here with the first Windows solution.

## Pull requests

Explain the user-visible effect, affected platform, test evidence, media provenance, and any dependency or license change. Do not attach private media to an issue or pull request.
