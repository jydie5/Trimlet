# Repository structure and platform ownership

- Status: Accepted
- Updated: 2026-08-16

## Decision

Trimlet uses one monorepo for the native macOS and Windows applications.

The applications do not share UI or playback source code. They share product requirements, normalized media concepts, export-plan behavior, fixtures, error identifiers, and release policy.

Different implementation languages are not sufficient reason to split repositories. A split would make it easier for export behavior and user terminology to drift while the product is still being defined.

## Ownership boundaries

| Path | Purpose | Expected reviewers |
|---|---|---|
| `apps/macos/` | SwiftUI, AVFoundation, VideoToolbox adapters | macOS owner |
| `apps/windows/` | WinUI, Windows media, hardware encoder adapters | Windows owner |
| `contracts/` | Machine-readable shared behavior and fixtures | both platform owners |
| `docs/REQUIREMENTS.md` | shared product requirements | both platform owners |
| `docs/PLATFORM_CONTRACT.md` | cross-platform semantics | both platform owners |
| `docs/legal/` | distribution and compliance policy | release owner |

GitHub usernames are intentionally not guessed. Add `.github/CODEOWNERS` after the macOS owner, Windows owner, and release owner accounts are known.

## Change rule

- A platform-only implementation change may stay within its application directory.
- A visible behavior change must update the shared requirement or contract.
- A serializer, error identifier, or export-plan change must update its fixture.
- CI for one platform must not require the other platform's SDK.
- Release readiness is evaluated for each distributable artifact, not merely for the repository as a whole.

## When to reconsider separate repositories

Reconsider only when at least one of these becomes true:

- the applications become separately named or licensed products;
- access control or security boundaries must differ;
- release governance is independent and shared-contract changes are rare;
- repository size or CI cost materially blocks either team.

If a split occurs, move `contracts/` and shared product documents into a third versioned specification repository. Do not duplicate them independently into the two application repositories.
