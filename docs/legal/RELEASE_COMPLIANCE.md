# GitHub release compliance checklist

- Status: historical source-only releases; Windows unsigned portable Beta 1 authorized on 2026-09-09
- Updated: 2026-09-09

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

## Windows Early Access publication record

Release `v0.3.0-early-access.1` is approved only as a GitHub source prerelease. It may include the C#/WinUI source, tests, workflows, and documentation. It must not attach an installer, `.exe`, MSIX, FFmpeg/ffprobe binary, generated test media, or build output.

The release notes and README must state that this is an unpackaged developer build, describe the separately installed FFmpeg requirement, and name the automatic-proxy and VFR-navigation limitations. Creating the tag remains conditional on the final repository readiness scan and Windows CI passing.

## macOS Beta 1 publication record

Release `v0.3.0-beta.1` is approved as a GitHub source-only prerelease after the focused interaction check accepted the multi-range workflow on 2026-08-28. It may include Swift source, Windows source, tests, workflows, contracts, and documentation. It must not attach `Trimlet.app`, a DMG, FFmpeg/ffprobe binaries, generated test media, or developer-machine build output.

The release notes and README must disclose the separately installed FFmpeg requirement, the lack of production signing/notarization and binary distribution, and the remaining media-quality evaluation. The tag is created from `main` only after Mac, Windows, shared-contract, security, and source-release readiness checks pass.

## Initial publication policy

The first public publication is source-only. It must not attach `dist/Trimlet.app`, a DMG, FFmpeg binaries, generated test media, or developer-machine caches.

README installation instructions may direct users to obtain FFmpeg separately, but must not imply that the FFmpeg project endorses Trimlet.

## Future binary release gate

### Windows Beta 2 automatic acquisition — 2026-09-09

The owner requested removal of manual FFmpeg preparation. Beta 2 adds consent-based direct acquisition from a pinned upstream LGPL 3.0 release, with size/hash verification, bounded extraction, cancellation and per-user storage. Trimlet release archives still contain no FFmpeg files. This is not authorization to mirror arbitrary FFmpeg builds or claim complete patent/copyright clearance. See [the exact package and distribution boundary](VIDEO_TOOL_ACQUISITION.md). A future offline bundled build still needs corresponding-source and dependency review.

### Windows unsigned portable beta exception — 2026-09-09

The repository owner explicitly requested a downloadable Windows binary beta. `v0.4.0-beta.1` therefore permits a self-contained, unsigned x64 ZIP as a GitHub prerelease. This does not change the historical source-only tags or approve a signed/production release. No Mac binary is published under this tag.

The archive must contain no FFmpeg/ffprobe, sample media, credentials or developer caches. Include the MIT license, resolved NuGet package license/notice files, a dependency inventory and per-file hashes, plus an archive SHA-256. Runtime files are obtained by the pinned project's .NET publish pipeline, not copied from arbitrary machine installations. Publish with trimming disabled to retain JSON/XAML reflection support.

Document the unsigned status, separate FFmpeg requirement and outstanding clean-machine, original artwork/signing and expanded human/media verification. A successful developer-machine archive test is not clean-machine certification. The full production gate below remains open; the FFmpeg redistribution steps apply only if future artifacts actually bundle FFmpeg.

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
