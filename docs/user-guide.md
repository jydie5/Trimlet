# Getting started with Trimlet

[Back to the app](../README.md) · [日本語](user-guide.ja.md)

This guide is for using the Windows app without writing code.

## 1. Get the app

[Download the Windows ZIP](https://github.com/jydie5/Trimlet/releases/download/v0.4.0-beta.1/Trimlet-0.4.0-beta.1-win-x64.zip), right-click it and choose **Extract All**. Keep all extracted files together; do not run from inside the ZIP.

This is an experimental x64 build, tested on the developer's Windows 11 machine. Windows 10 and ARM acceptance are not completed. There is no ready-to-run Mac download yet.

## 2. Add the video tools

The current beta does not include FFmpeg. **No programming or PowerShell command is required, but adding files is necessary.**

1. Visit the [FFmpeg download page](https://ffmpeg.org/download.html). Under **Windows EXE Files**, follow a listed provider, not the “Download Source Code” link. These compiled builds are supplied by third parties.
2. Download and extract a Windows x64 build. A **static** build avoids needing additional FFmpeg DLLs for this procedure.
3. Find `ffmpeg.exe` and `ffprobe.exe`, usually under `bin`, and copy them into the same folder as `Trimlet.Windows.exe`.
4. Read the provider's terms and retain its license documents. These are personal setup instructions, not permission to redistribute Trimlet with FFmpeg bundled.

An existing FFmpeg installation may already work. If you are unsure, [ask for help](https://github.com/jydie5/Trimlet/issues/new?template=bug_report.yml).

## 3. Make your first edit

Double-click `Trimlet.Windows.exe`. A separate .NET installation or a PowerShell launcher is normally unnecessary.

1. Choose **Open video**.
2. Move to the start of the part you want and set **IN**.
3. Move to its end and set **OUT**, after IN.
4. **Add to sequence**. Repeat for each part you want to keep.
5. Arrange your clips and preview the sequence.
6. Choose **Export MP4** and select an output folder.

**Fast** prioritizes speed and may move cut points. **Accurate** prioritizes your chosen points and takes longer because it re-encodes the video. Check the exported video afterward.

## Save and resume

Use **Save** to create a `.trimlet` project and **Project → Open project** to resume it. Projects do not embed the video. Keep the source video, and move it together with the project. On Windows, save both on the same drive. IN/OUT drafts that have not been added are not saved.

## Troubleshooting

- **Unknown publisher warning:** this beta is unsigned. Check that you obtained it from the release linked above, not an unknown provider. Do not disable security features. Stop if you are unsure.
- **A .NET installation prompt:** extract the entire current ZIP and avoid mixing it with an old EXE or a developer build.
- **FFmpeg not found:** check that both executables are beside the Trimlet EXE, then restart Trimlet.
- **Video will not open or export:** some formats are unsupported. Try a short video first.
- **Report a problem:** include your Windows and Trimlet versions, what you tried and what happened in a [bug report](https://github.com/jydie5/Trimlet/issues/new?template=bug_report.yml). “Unknown” is fine where needed. Do not attach private videos or identifying screenshots.

Back up important videos and projects. Broad testing across machines and media is not complete.

[Release details](https://github.com/jydie5/Trimlet/releases/tag/v0.4.0-beta.1) · [Distribution terms and limitations](../apps/windows/BETA_DOWNLOAD.md)
