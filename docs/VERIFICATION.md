# Mac verification record

## Mac multi-range 0.3 developer verification

- Verified: 2026-08-25
- Host: Apple silicon (`arm64`), macOS 26.5.2
- Toolchain: Apple Swift 6.3
- Local FFmpeg: 7.1.1 with VideoToolbox enabled

### Automated result

- Release build passed.
- `TrimletCoreChecks` passed integer timestamp, ordered edit-list, overlap rejection, mutation, Fast-candidate, selected-audio mapping, VideoToolbox, M2TS audio conversion, and MOV PCM-to-AAC compatibility checks.
- `TrimletIntegrationChecks` generated a 12-second H.264 source with three visible color sections and two audio streams, then exported three non-chronological retained ranges in edit-list order.
- Accurate combined output passed video/audio presence, `3.800 s` duration, blue → red → green order, and selected `880 Hz` audio checks.
- Fast combined output passed video/audio presence, `10.000 s` candidate duration, blue → red → green order, and selected `880 Hz` audio checks.
- Shared shell contract validation passed 2 export cases, 2 edit-list cases, and 9 shared error codes.
- Release-readiness, shell syntax, and whitespace checks passed.
- Release application bundle build, ad-hoc signing, launch, and initial multi-range UI rendering passed.
- GitHub Draft PR #4 passed both macOS build/integration jobs, both Windows validation jobs, shared contract validation, and repository security checks.
- The 2026-08-25 range-flow redesign opened with both boundaries unset and steps 2/3 unavailable. An accessibility-driven UI check set IN at 0 s, moved to 5 s, set OUT, added the subclip to the editing sequence, and confirmed that the editor reset to empty new-subclip mode. Selecting the clip visibly entered Trim mode.
- The professional terminology pass rendered Source Timeline, Subclip, Clip, Editing Sequence, and Trim consistently. A three-clip UI exercise dragged a clip to a new position; the cards reordered immediately, the moved clip remained selected, and the trim controls stayed usable.
- The earlier position-number card experiment was removed after review. The accepted card hierarchy is representative thumbnail, editable stable clip name, and IN–OUT range; sequence order is communicated by horizontal placement.
- A generated H.264 sample produced a visible IN-adjacent thumbnail on its clip card. The default `trimlet-sample · 00:00:00:00` name was changed to `Opening IO`; the card updated without changing its thumbnail, IN–OUT range, or segment identity. Typing I/O while the name field was focused did not trigger IN/OUT shortcuts.
- The reported “first clip disappeared after making three” case was reproduced as an accidental update: the UI had two cards, remained in Trim mode, and the first card's original-name timecode no longer matched its changed range. After separating selection from Trim Edit, a test selected the first card before each new IN/OUT operation and still produced three distinct cards; the editor stayed in Add mode until the explicit Trim Edit button was used.
- The 2026-08-26 interaction pass loaded the 8-second H.264 sample without presenting the full-screen keyframe-analysis panel; the source timeline remained interactive and showed the ready count inline.
- J started reverse 1x, K stopped, and repeated L advanced from forward 1x to 2x with matching direction/speed labels and visible playhead movement. The same J/K/L controls remained present on screen.
- An IN/OUT draft rendered as a translucent purple range with a dashed edge. After Add to Sequence, the purple draft disappeared, the retained range rendered blue, and the editor reset for a new subclip.
- A synthetic pointer drag moved the slider repeatedly across the source and released near 5 seconds. Video and timecode followed the drag, and the final exact seek settled at `00:00:05:03` on the 30 fps test source.
- On 2026-08-28, the user accepted the focused interaction checkpoint covering visible `J Reverse`／`K Stop`／`L Forward` meaning, visible `I`／`O` hints, purple draft-to-blue retained-range feedback, two-finger seek, three retained clips, and repeated playback controls. This acceptance authorized committing and handing the interaction contract to the Windows implementation turn.

Run the principal checks with:

```text
swift build -c release --package-path apps/macos
swift run -c release --package-path apps/macos TrimletCoreChecks
swift run -c release --package-path apps/macos TrimletIntegrationChecks
scripts/validate-contracts.sh
scripts/check-release-readiness.sh
```

### Remaining 0.3 gate

Automated and developer-side verification is complete for the Mac 0.3 implementation, and the focused interaction checkpoint passed on 2026-08-28. Broader release evaluation still covers edit-list output timing, M2TS proxy behavior, long-media responsiveness, A/V sync, cancellation, and visual density using `HUMAN_CHECK.md`.

## Mac PoC 0.1/0.2 verification

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
