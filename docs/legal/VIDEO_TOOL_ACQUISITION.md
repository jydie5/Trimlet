# Windows video-tool acquisition record

Date: 2026-09-09. Engineering record, not legal advice or certification.

## Distribution boundary

The owner requested removal of manual FFmpeg setup with attention to copyright. Windows 0.4.0-beta.2 implements an explicit first-run download, **not an offline FFmpeg-bundled release**. The app identifies the upstream distributor and terms, asks for agreement, then downloads directly from GitHub. No request is made until the user chooses to prepare tools. No media is sent. Normal connection information reaches GitHub. Users may cancel and continue without automatic acquisition.

Trimlet's uploaded ZIP still includes no FFmpeg binaries/libraries. This distinction is not a license exemption: FFmpeg retains its terms, and a future mirrored/bundled distribution requires exact corresponding sources and dependency compliance. We have not assembled those sources for redistribution and do not claim that task complete. No dependency is copied from the developer's installed FFmpeg.

## Pinned package actually inspected

- Distributor: [BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds), a third party, not the FFmpeg project itself.
- Release: [autobuild-2026-08-31-13-27](https://github.com/BtbN/FFmpeg-Builds/releases/tag/autobuild-2026-08-31-13-27).
- Archive: `ffmpeg-n8.1.2-50-g1a748fe2cd-win64-lgpl-shared-8.1.zip`.
- Size: 70,835,150 bytes. SHA-256: `e9712ffbdb03ef71bbab660c75b835bfe698ef6fad0247c76d8d394a39a3db63`.
- Actual `ffmpeg -version`: `n8.1.2-50-g1a748fe2cd-20260831`, GCC 15.2.0.
- Actual package LICENSE.txt: LGPL version 3. Configure includes `--enable-version3`, `--enable-shared`, `--disable-static`, `--disable-libx264`, `--disable-libx265`; no `--enable-gpl` or `--enable-nonfree` observed.
- The downloaded archive is preserved in full during extraction, including LICENSE.txt, headers, documentation and binaries. Files are not renamed/obfuscated and can be replaced through the existing manual tool configuration. Trimlet calls executables as separate processes; it does not link FFmpeg into its .NET assemblies.
- Source/build references: [FFmpeg source](https://github.com/FFmpeg/FFmpeg), [upstream build scripts and dependency recipes](https://github.com/BtbN/FFmpeg-Builds). These links are not represented as a complete corresponding-source archive hosted by Trimlet.

## Safety and lifecycle

HTTPS, fixed URL/version/size and SHA-256; do not resolve `latest` at runtime. Validate before extraction or execution. Reject traversal, alternate streams, symlinks, duplicate case-insensitive paths, excessive files/expanded size. Use a unique staging directory, cancel/clean up failed preparation, then move the completed directory atomically. Do not overwrite an existing installation. Preserve package terms, use per-user storage and make no PATH/registry changes.

Upstream monthly builds are currently retained for two years, not indefinitely. A removed asset must cause an actionable failure, not a silent change of binary. Maintainers must review a new version and hash before updating the pin. Users already set up can keep editing offline. Removing Trimlet's ZIP does not remove per-user downloaded tools; close Trimlet before manually removing its VideoTools folder if desired.

## Licensing sources and unresolved items

- [FFmpeg license guidance](https://ffmpeg.org/legal.html) distinguishes optional GPL/nonfree configurations and describes source/notice obligations for redistribution.
- [LGPL 3.0](https://www.gnu.org/licenses/lgpl-3.0.html) applies to this selected package. Do not describe it generically as LGPL 2.1.
- [BtbN build variants and retention](https://github.com/BtbN/FFmpeg-Builds) describe the LGPL variants and source build mechanism.

Copyright compliance does not establish H.264/AAC or other codec patent clearance. Commercial distribution or other significant exposure needs jurisdiction-specific professional review. Signing, original release artwork, clean-machine acceptance and broader media coverage are still open. Do not advertise this as a signed, offline-ready, patent-cleared or universally supported release.
