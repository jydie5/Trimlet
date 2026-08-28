# Windows Early Access handover for the macOS owner

- Prepared: 2026-08-21
- Windows release: `v0.3.0-early-access.1`
- Audience: macOS implementation owner

This records the inbound Windows-to-macOS handover at Early Access 1. The macOS implementation subsequently advanced to `v0.3.0-beta.1`; the current outbound requirements for the Windows catch-up turn are in `apps/windows/handover.md` and `docs/PLATFORM_CONTRACT.md`.

## What reached parity

Windows now implements the same core single-video workflow as the macOS PoC:

1. Open or drop MP4, MOV, M2TS, or MTS.
2. Play, scrub, and move by one frame, ten frames, or five seconds.
3. Set one IN/OUT range and preview it.
4. Inspect keyframes for a Fast candidate.
5. Export in Fast or Accurate mode without modifying the source.
6. Report progress, allow cancellation, validate temporary output, and reveal the completed file.

The shared timestamp, exclusive-OUT, export-mode, error, and fixture contracts were not weakened for Windows.

## Important differences

| Area | macOS PoC | Windows Early Access |
|---|---|---|
| Preview fallback | Automatically creates and caches a proxy when direct playback is unsuitable | No automatic proxy yet; reports preview failure |
| Frame movement | AVFoundation playback path | Nominal rational frame-rate movement; VFR source-PTS stepping remains open |
| Audio choice | Current Mac workflow selects its export audio implicitly | Explicit audio-stream picker |
| Accurate encoder | VideoToolbox path with current PoC settings | Probes Windows hardware/software H.264 candidates with a real encode |
| Distribution | Ad-hoc local app build | Unpackaged, framework-dependent local build |

Therefore “parity” means the primary editing and export workflow is aligned, not that every fallback and distribution capability is equal.

## Windows decisions worth reviewing on macOS

1. Explicit audio-stream selection may be useful when sources contain commentary or multiple languages.
2. Encoder discovery based on a real test encode is more reliable than list-only capability detection.
3. Windows validates the temporary output before finalizing and keeps redacted diagnostics under the user-local app data directory. Confirm the macOS validation and log presentation remain equivalent.
4. The working canvas no longer displays the public tagline. `docs/PRODUCT_DESIGN.md` now places brand copy in README, release, or About surfaces unless it guides the current action.

These are review candidates, not automatic requests to copy WinUI structure into SwiftUI.

## Requested macOS follow-up

- Review `docs/PRODUCT_DESIGN.md` and confirm the Mac work surface follows the same media-first, low-copy principle.
- Decide whether explicit audio-stream selection belongs in the shared requirements.
- Compare Fast candidate timing and Accurate output tolerance using the same fixture semantics.
- Keep automatic proxy behavior as the current Mac advantage until Windows implements an equivalent platform-native flow.
- Request both platform owners on any change to `docs/PLATFORM_CONTRACT.md`, `contracts/`, timing semantics, or export-mode meaning.

## Validation references

- Windows entry and limitations: `apps/windows/README.md`
- Windows manual check: `apps/windows/HUMAN_CHECK.md`
- Windows maintainer notes: `apps/windows/handover.md`
- macOS verification baseline: `docs/VERIFICATION.md`
- Shared behavior: `docs/PLATFORM_CONTRACT.md`
- Release scope: `docs/releases/v0.3.0-early-access.1.md`

The next cross-platform milestone should close preview-proxy and VFR navigation gaps before either side claims complete feature parity.
