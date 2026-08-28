# Trimlet for Windows human check

This check covers the Windows multi-range parity candidate based on the accepted macOS `v0.3.0-beta.1` interaction contract.

## Start

From PowerShell:

```powershell
Set-Location (Join-Path $HOME 'trimlet')
.\apps\windows\run-human-check.ps1
```

The script validates shared JSON contracts, runs the Windows automated tests, performs synthetic single- and multi-range Fast/Accurate exports, validates the outputs, builds the app, and launches Trimlet.

Prerequisites:

- .NET SDK 10.0.400 (the script also recognizes `C:\Users\<name>\.dotnet-sdk-10\dotnet.exe`).
- `ffmpeg` and `ffprobe` on `PATH`, specified by `TRIMLET_FFMPEG` / `TRIMLET_FFPROBE`, or placed beside the built app.

## Check with local media

Use non-sensitive MP4 or MOV media first. M2TS/MTS playback depends on codecs available in Windows.

1. Confirm the app opens with the Trimlet title and no installer.
2. Select **Open video**, choose a supported local file, and confirm its name and compact media summary appear. The full path is available as a tooltip rather than permanent interface copy.
3. Repeat by dragging a supported file onto the window.
4. Confirm the media summary shows duration, dimensions, and rational frame rate. The audio picker should stay hidden for one stream and appear only when multiple streams exist.
5. Play, pause, drag the timeline, and use the five-second and frame navigation buttons. Also check Space, Left/Right, Shift+Left/Right, I, and O. Dragging should stay responsive and release should settle on the final position.
6. Press **J Reverse**, **K Stop**, and **L Forward**. Repeated J/L presses should show and apply 1x, 2x, 4x, and 8x. Pressing the opposite direction should move the signed level toward stop.
7. Move to a position and select **① Set IN [I]**. Move later and select **② Set OUT [O]**. Confirm both times and the selected duration update. The draft must appear as a purple fill with a dashed boundary, distinct from retained clips without relying on color alone. Internally, OUT remains exclusive.
8. Select **③ Add to sequence**. Confirm the draft clears, a blue retained range appears, and a card shows a thumbnail, editable name, source IN–OUT, duration, and no sequence-position number.
9. Add a second non-overlapping clip. Confirm overlap is rejected but an adjacent half-open range is allowed. Selecting a card must not enter trim mode; only **Trim edit** may load and update that clip.
10. Rename, trim, delete, drag-reorder, and use the earlier/later buttons. Confirm stable clip identity and Undo/Redo behavior. Then select **Preview sequence** and confirm playback follows output order while skipping source gaps.
11. Select **Fast**. Confirm every retained clip has a keyframe-compatible candidate before export; candidates may expand beyond requested boundaries.
12. Export Fast, confirm combined weighted progress, reveal the output, and verify clip order. Repeat with **Accurate** and confirm the combined duration closely matches the requested total.
13. Start a longer Accurate export, press **Cancel**, and confirm no `.partial.mp4` or operation work directory remains in the destination.
14. Switch the Windows display language between English and Japanese, restart the app, and confirm the visible UI follows the selected language.
15. Try a file path containing spaces, Japanese text, quotes, or emoji. The original file must remain unchanged and a unique destination name must be chosen when a file already exists.

Diagnostics for a failed operation are stored under `%LOCALAPPDATA%\Trimlet\Logs` with path-like arguments redacted.

## Expected limitations

- Frame navigation uses the inspected nominal rational frame rate. Variable-frame-rate presentation-timestamp stepping is not yet implemented.
- Automatic proxy generation for media that Windows-native playback cannot decode is not yet implemented; the app reports the preview failure without closing.
- No MSIX or signed binary is produced. This is an unpackaged, framework-dependent developer build.
