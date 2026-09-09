# Windows Beta 2 — 0.4.0-beta.2

[はじめて使う方へ（コード不要の手順）](../../docs/user-guide.ja.md) / [First-time setup without coding](../../docs/user-guide.md).

This page records version-specific distribution requirements. Existing release ZIPs retain the documentation bundled at publication time; the current user guides above may be clearer or newer.

## 起動 / Run

1. `Trimlet-0.4.0-beta.2-win-x64.zip` をフォルダーごと展開します。
2. 展開先の `Trimlet.Windows.exe` を起動します。EXEだけを移動しないでください。
3. 上部の「動画ツール」で配布元と条件を確認し、「同意して準備する」を押します。初回のみ約71MBをGitHubから取得します。動画は送信しません。既存のFFmpegを使える場合は取得不要です。

Extract the entire ZIP and run `Trimlet.Windows.exe`. Keep all files together. Choose Video tools, review the upstream terms and select Agree and prepare. Initial setup downloads about 71 MB from GitHub; it does not send video. Existing usable FFmpeg installations can be retained.

- Windows x64 only; tested on the developer's Windows 11 machine. Clean-machine, Windows 10, ARM64 and x86 acceptance are not completed.
- .NET 10 and Windows App SDK runtime files are included. No separate .NET installer or PowerShell launcher is intended to be needed.
- This is an **unsigned, experimental portable beta**, not an installer or a production-certified release. Windows may warn about an unknown publisher. No security-setting changes are required or recommended by this guide.
- FFmpeg/ffprobe and demo media are **not included in the Trimlet ZIP**. With user agreement, the app fetches the pinned LGPL 3.0 build directly from BtbN's GitHub release, retaining its package/license files under `%LOCALAPPDATA%/Trimlet/VideoTools/`. No system PATH changes or administrator access. First-time offline setup is not supported. FFmpeg is an independent project: https://ffmpeg.org/download.html
- Acquisition/version/license details: https://github.com/jydie5/Trimlet/blob/main/docs/legal/VIDEO_TOOL_ACQUISITION.md . This is not a blanket copyright or patent clearance; redistributing a downloaded FFmpeg installation requires a separate corresponding-source and dependency review.
- Save and retain source media alongside your `.trimlet` project; the project does not embed video. Only added clips are saved, not an uncommitted IN/OUT draft.
- Expanded gesture/DPI/theme, source-relink cases, and broad real-media/HDR/interlaced testing remain pending. Back up important projects and verify exported files.
- `LICENSE`, `THIRD_PARTY_NOTICES.md`, `licenses/`, `dependency-inventory.json` (resolved build and runtime packages), and `file-manifest.json` are included. The inventory is not a certification or a standardized SPDX/CycloneDX SBOM.
- Bundled Microsoft components are provided under their accompanying terms in `licenses/`, not under Trimlet's MIT license. Use and redistribution of those components require agreement to those terms. Read them before using or redistributing the archive.

## Source and feedback

https://github.com/jydie5/Trimlet/releases/tag/v0.4.0-beta.2

https://github.com/jydie5/Trimlet/issues
