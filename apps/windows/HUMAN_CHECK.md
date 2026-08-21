# Trimlet for Windows human check

This check covers the native Windows inspection, range-selection, and MP4-export slice.

## Start

From PowerShell:

```powershell
Set-Location (Join-Path $HOME 'trimlet')
.\apps\windows\run-human-check.ps1
```

The script validates shared JSON contracts, runs the Windows automated tests, performs synthetic Fast and Accurate exports, validates both outputs, builds the app, and launches Trimlet.

Prerequisites:

- .NET SDK 10.0.400 (the script also recognizes `C:\Users\<name>\.dotnet-sdk-10\dotnet.exe`).
- `ffmpeg` and `ffprobe` on `PATH`, specified by `TRIMLET_FFMPEG` / `TRIMLET_FFPROBE`, or placed beside the built app.

## Check with local media

Use non-sensitive MP4 or MOV media first. M2TS/MTS playback depends on codecs available in Windows.

1. Confirm the app opens with the Trimlet title and no installer.
2. Select **Open video**, choose a supported local file, and confirm its name and compact media summary appear. The full path is available as a tooltip rather than permanent interface copy.
3. Repeat by dragging a supported file onto the window.
4. Confirm the media summary shows duration, dimensions, rational frame rate, and the available audio streams. Detailed inspection data stays out of the main work surface.
5. Play, pause, drag the timeline, and use the five-second and frame navigation buttons. Also check Space, Left/Right, Shift+Left/Right, I, and O.
6. Move to a position and select **Set IN**. Move later and select **Set OUT**. Confirm both times and the selected duration update. Internally, OUT remains an exclusive boundary.
7. Confirm Trimlet rejects IN at or after OUT and OUT at or before IN.
8. Select **Fast**. Confirm the keyframe candidate appears below the range track when analysis completes; it may expand beyond the selected range.
9. Select **MP4を書き出す…**, choose a destination folder, and confirm progress is shown. When complete, use **出力を表示** and play the output.
10. Repeat with **Accurate**. Confirm its duration closely matches the selected range and the plan uses an available H.264 encoder plus AAC.
11. Start a longer Accurate export, press **キャンセル**, and confirm no `.partial.mp4` remains in the destination.
12. Switch the Windows display language between English and Japanese, restart the app, and confirm the visible UI follows the selected language.
13. Try a file path containing spaces, Japanese text, quotes, or emoji. The original file must remain unchanged and a unique destination name must be chosen when a file already exists.

Diagnostics for a failed operation are stored under `%LOCALAPPDATA%\Trimlet\Logs` with path-like arguments redacted.

## Expected limitations

- Frame navigation uses the inspected nominal rational frame rate. Variable-frame-rate presentation-timestamp stepping is not yet implemented.
- Automatic proxy generation for media that Windows-native playback cannot decode is not yet implemented; the app reports the preview failure without closing.
- No MSIX or signed binary is produced. This is an unpackaged, framework-dependent developer build.
