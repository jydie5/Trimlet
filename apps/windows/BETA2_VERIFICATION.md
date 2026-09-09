# Windows Beta 2 verification — 2026-09-09

Scope: first-use video-tool acquisition. This is not an offline FFmpeg bundle, legal certification or comprehensive human acceptance.

## Completed

- 46 tests passed: 5 shared-contract and 41 media/platform tests. New cases cover safe extraction, traversal/alternate stream rejection, case-insensitive duplicate rejection, pre-cancelled extraction, truncated downloads and wrong SHA-256 at the correct size.
- Direct upstream download succeeded through the production `VideoToolSetup.InstallAsync` service from an explicit CLI integration check. Size/SHA-256, extraction and atomic per-user installation passed.
- With PATH reduced to Windows directories and FFmpeg override variables cleared, the acquired LGPL build passed inspection, VFR frame timestamps, Fast/Accurate export, ordered multi-range output, selected audio, M2TS/AC-3 proxy generation/cache reuse and safe filenames/finalization. A separate developer FFmpeg generated synthetic fixtures only; export/inspection used the acquired build.
- Native Debug UI: missing-tools notice, distributor/terms links and consent dialog inspected; Cancel returned to enabled controls without initiating a download.
- Release ZIP extracted into a separate directory. All 568 per-file manifest entries matched. No FFmpeg/ffprobe/libavcodec files are in the ZIP.
- Extracted app launched from a different working directory with nonexistent .NET root variables and no FFmpeg PATH entries. Process modules loaded .NET/WinUI from the extracted folder. The synthetic three-clip project, media preview and thumbnails loaded using the previously acquired tools.

## Artifact

- `Trimlet-0.4.0-beta.2-win-x64.zip`, 109,050,821 bytes.
- SHA-256: `a27da4d1bfd31120c216f705dc8170e77e4a706c996f360649c60786adcc5370`.
- .NET SDK 10.0.400; self-contained .NET and Windows App SDK; trimming disabled.

## Pending

Full native consent → network progress → completion/cancellation acceptance by the user, simulated disconnect/server-removal recovery, other machines/DPI/themes, and broad media coverage. Actual network preparation was exercised through the same service in the CLI, not represented as a full UI download acceptance result. Code signing, clean-machine certification and offline redistribution/corresponding-source work are not completed. Beta 1 assets and checksums remain unchanged.

[Pinned package and licensing boundary](../../docs/legal/VIDEO_TOOL_ACQUISITION.md).
