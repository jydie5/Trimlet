# Windows Beta 1 — 0.4.0-beta.1

## 起動 / Run

1. `Trimlet-0.4.0-beta.1-win-x64.zip` をフォルダーごと展開します。
2. 展開先の `Trimlet.Windows.exe` を起動します。EXEだけを移動しないでください。
3. 動画処理には別途 `ffmpeg.exe` と `ffprobe.exe` が必要です。両方をPATHに追加するか、環境変数 `TRIMLET_FFMPEG` / `TRIMLET_FFPROBE` に各実行ファイルの絶対パスを設定し、アプリを再起動してください。

Extract the entire ZIP and run `Trimlet.Windows.exe`. Keep the accompanying files together. Install FFmpeg and ffprobe separately and expose both on PATH, or set their absolute paths in `TRIMLET_FFMPEG` / `TRIMLET_FFPROBE` before launching.

- Windows x64 only; tested on the developer's Windows 11 machine. Clean-machine, Windows 10, ARM64 and x86 acceptance are not completed.
- .NET 10 and Windows App SDK runtime files are included. No separate .NET installer or PowerShell launcher is intended to be needed.
- This is an **unsigned, experimental portable beta**, not an installer or a production-certified release. Windows may warn about an unknown publisher. No security-setting changes are required or recommended by this guide.
- FFmpeg/ffprobe and demo media are **not included**. FFmpeg is an independent project: https://ffmpeg.org/download.html
- Save and retain source media alongside your `.trimlet` project; the project does not embed video. Only added clips are saved, not an uncommitted IN/OUT draft.
- Expanded gesture/DPI/theme, source-relink cases, and broad real-media/HDR/interlaced testing remain pending. Back up important projects and verify exported files.
- `LICENSE`, `THIRD_PARTY_NOTICES.md`, `licenses/`, `dependency-inventory.json` (resolved build and runtime packages), and `file-manifest.json` are included. The inventory is not a certification or a standardized SPDX/CycloneDX SBOM.
- Bundled Microsoft components are provided under their accompanying terms in `licenses/`, not under Trimlet's MIT license. Use and redistribution of those components require agreement to those terms. Read them before using or redistributing the archive.

## Demo footage / デモ動画

The README screenshot uses original synthetic footage, not a downloadable tutorial video. [Generation instructions / 生成手順](https://github.com/jydie5/Trimlet/blob/main/docs/WINDOWS_DEMO.md).

## Source and feedback

https://github.com/jydie5/Trimlet/releases/tag/v0.4.0-beta.1

https://github.com/jydie5/Trimlet/issues
