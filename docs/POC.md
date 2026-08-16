# Trimlet PoC

## Purpose

This proof of concept is a real native macOS application for human evaluation. It is not a static screen mock.

The PoC validates whether the basic Trimlet interaction feels understandable and useful before the production architecture is frozen.

## Human-check scope

- Open a local MP4, MOV, M2TS, or MTS file through a dialog or drag and drop.
- Play, pause, scrub, jump five seconds, and step one or ten frames in either direction.
- View the current position as `HH:MM:SS:FF`.
- Mark one IN and OUT point.
- See and preview the selected range.
- Export the range to MP4 using Fast or Accurate mode through the locally installed FFmpeg.
- See keyframe marks and the Fast-mode candidate range before export.
- See percentage progress for export, cancel it, and verify that the UI stays responsive.
- Validate video, expected audio, and duration before exposing the completed file.

## Build and launch without Xcode

The current Mac has Swift and the macOS SDK but does not have the full Xcode application installed. The PoC can still be built and launched.

In Finder, open the `Trimlet` folder and double-click `run-poc.command`. The first launch builds a local ad-hoc-signed application and opens:

```text
dist/Trimlet.app
```

The script does not install anything globally and does not publish anything to GitHub.

## Known PoC limitations

- M2TS/MTS is converted to a cached H.264/AAC preview proxy automatically. Proxy preparation is visible, but cache cleanup controls are not yet exposed.
- Fast mode inherits keyframe-boundary behavior from stream copy.
- Synthetic or unusual transport streams with no usable keyframe near the selected range may require Accurate mode.
- Accurate mode uses a fixed H.264 target bitrate of 12 Mbps for evaluation.
- Keyframe marks are packet-level random-access hints. A detailed per-frame I/P/B inspector is deferred.
- Fast candidate boundaries are explanatory estimates; the finished file remains the final authority.
- Export writes to a hidden temporary file, validates it with ffprobe, and only then moves it to the chosen destination.
- Frame timecode is based on the nominal frame rate; variable-frame-rate display needs a timestamp-aware production design.
- The PoC expects FFmpeg at `/opt/homebrew/bin/ffmpeg` or `/usr/local/bin/ffmpeg`.
- The Swift Package launch is suitable for evaluation but is not a signed or notarized `.app` release.

These limitations are visible boundaries of the PoC, not the final product requirements.

Human feedback and the next iteration are tracked in `HUMAN_CHECK_2026-08-14.md` and `BACKLOG.md`.
