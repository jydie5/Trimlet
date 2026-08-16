# Mac PoC verification record

- Verified: 2026-08-14
- Host: Apple silicon, macOS 26.5.2

## Build and packaging

- Debug build: passed with Swift 6.3.
- Release build: passed.
- Core behavior checks: all passed.
- Application bundle: arm64 Mach-O.
- Local ad-hoc signature: `codesign --verify --deep --strict` passed.
- `Info.plist`: `plutil -lint` passed.
- Application process launched from `dist/Trimlet.app`.
- Native window rendered and accepted a video through the Open panel.

## Core behavior checks

The executable check target covers:

- Valid, empty, inverted, and partial trim ranges.
- Clamping range points to source duration.
- `HH:MM:SS:FF` formatting and invalid time handling.
- Fast mode seeking before input opening.
- Accurate mode seeking after input opening so decoding can reach an exact boundary.
- M2TS Fast mode video copy with AAC audio conversion.
- Accurate mode VideoToolbox H.264 selection.
- Japanese and space-containing paths remaining a single process argument.

Run with:

```text
swift run --package-path apps/macos TrimletCoreChecks
```

## Playback UI

- Generated 8-second H.264/AAC MP4 opened in the native player.
- Video frame rendered.
- Play command advanced the video.
- IN and OUT shortcuts changed the selected range and status text.
- Generated H.264/AC-3 M2TS created an H.264/AAC proxy in the Trimlet cache.
- The cached proxy opened and rendered while the UI retained the M2TS source identity.

## Export integration

Using a realistic one-second GOP H.264/AC-3 M2TS and a 1.5-to-4.0 second requested range:

| Mode | Output streams | Measured duration | Result |
|---|---|---:|---|
| Fast | H.264 + AAC | 2.571667 s | Passed; expected keyframe variance |
| Accurate | H.264 + AAC | 2.500000 s | Passed |

The Accurate command was verified with `-ss` after input opening. A synthetic M2TS with an intentionally extreme GOP was also tested and documented as requiring Accurate mode when no usable keyframe is available near the range.

## Remaining verification gate

## PoC 0.2 verification

- Option＋Left/Right moved an 8-second test video from 0 to exactly 5 seconds.
- Fifty visible play/pause button activations at 200 ms intervals completed with the final icon and player state aligned.
- An 8-second MP4 exposed eight keyframe marks and a Fast candidate boundary on the timeline.
- A 5 minute 10 second MP4 exposed 155 keyframes without blocking timeline interaction.
- Accurate export displayed determinate progress (including 61% / 189.7 s), stayed responsive, and reached completion.
- The long Accurate result contained H.264 video, AAC audio, and exactly 310.000000 seconds according to ffprobe.
- Both short and long exports were written to hidden temporary paths, validated, then moved to their chosen final names. No temporary MP4 remained.
- Cancelling a long Accurate export stopped FFmpeg, displayed a distinct cancelled result, and left neither a chosen output nor a hidden temporary MP4.
- The export progress parser was exercised with repeated FFmpeg progress blocks.

Automated and developer-side verification is complete for PoC 0.2. The remaining gate is the user's human evaluation using `HUMAN_CHECK.md`.
