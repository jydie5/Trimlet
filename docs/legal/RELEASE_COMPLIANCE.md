# GitHub release compliance checklist

- Status: Source-only PoC release approved when the automated gate passes
- Updated: 2026-08-16

This is an engineering compliance gate, not legal advice.

## Source-only release gate

- [x] The collective copyright display name is confirmed as `Trimlet contributors`.
- [x] The MIT License is selected and present as root `LICENSE`.
- [x] Third-party notices explain that FFmpeg is separate.
- [x] No FFmpeg or ffprobe binary is tracked.
- [x] No generated application bundle is tracked.
- [x] No test video is tracked.
- [x] No obvious credential or private key is present in the current source tree.
- [x] Dependency inspection shows no Swift package dependency.
- [x] Mac and Windows implementation boundaries are documented.
- [x] Initial GitHub ownership is assigned to `@jydie5` in `.github/CODEOWNERS`.
- [x] GitHub private vulnerability reporting is enabled.
- [x] Dated preliminary name/trademark search record is present.
- [ ] Commercial trademark review is completed if the first release is commercial or materially promoted.
- [x] The final staged commit is rescanned before push.

Run `scripts/check-release-readiness.sh` before creating a tag.

## Initial publication policy

The first public publication is source-only. It must not attach `dist/Trimlet.app`, a DMG, FFmpeg binaries, generated test media, or developer-machine caches.

README installation instructions may direct users to obtain FFmpeg separately, but must not imply that the FFmpeg project endorses Trimlet.

## Future binary release gate

Before publishing a signed macOS or Windows binary:

1. Select and pin an exact FFmpeg release and build profile per platform.
2. Decide whether the build is LGPL or GPL and remove accidental GPL/nonfree features when they are not intended.
3. Record all configure flags, dependencies, patches, source revision, build scripts, and checksums.
4. Include all license texts, copyright notices, and corresponding-source access required by that build.
5. Review codec patent and royalty exposure separately from open-source copyright licensing.
6. Use an original Trimlet application icon.
7. Replace the PoC bundle identifier and complete signing/notarization or Windows signing.
8. Generate a software bill of materials for each artifact.
9. Test the release archive itself on a clean supported machine.

The locally installed Homebrew FFmpeg used during PoC development was configured with GPL features including x264/x265. It is not an approved redistribution artifact.

## Name and trademark gate

Exact-name web, J-PlatPat, USPTO, and TMview searches did not identify an exact active conflicting video editor at the time of review. J-PlatPat's similar-pronunciation search did identify candidates, including `DigitalTriplet` with class 9 coverage. See `TRADEMARK_SEARCH_2026-08-16.md`. This is not trademark clearance.

Before commercial distribution, search exact and similar marks in relevant jurisdictions using J-PlatPat, TMview/WIPO, and USPTO records, and obtain professional advice if risk or investment warrants it. Preserve dated search records under `docs/legal/` without storing third-party copyrighted result pages.
