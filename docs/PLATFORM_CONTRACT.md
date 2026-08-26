# Trimlet Mac/Windows platform contract

- Status: Draft 0.2
- Updated: 2026-08-24
- Purpose: Keep separately implemented Mac and Windows applications behaviorally aligned in one monorepo.

## 1. Boundary of this contract

This document defines what a user can expect from Trimlet regardless of operating system. It does not prescribe the Windows UI framework or playback API. Native code is isolated under `apps/macos` and `apps/windows`; shared behavior lives here and under `contracts`.

The Mac implementation currently uses SwiftUI, AVFoundation, ffprobe, FFmpeg, and VideoToolbox. Those are Mac adapters, not cross-platform product requirements.

## 2. Canonical product terms

Both implementations use these concepts and labels:

| Canonical concept | Japanese label | Meaning |
|---|---|---|
| Source media | 元動画 | The user-selected file; always treated as read-only |
| Current position | 現在位置 | Playback position expressed internally by source timestamp |
| IN point | IN点 | Inclusive start of the selected range |
| OUT point | OUT点 | End boundary of the selected range |
| Selected range | 選択範囲 | Interval from IN to OUT; valid only when OUT is later than IN |
| Source timeline | ソースタイムライン | Source-time view containing the playhead, IN/OUT, and retained ranges |
| Subclip | サブクリップ | A non-destructive source range created by setting IN and OUT |
| Clip | クリップ | A retained subclip with a stable identity in the editing sequence |
| Clip name | クリップ名 | A user-editable label attached to clip identity, independent of sequence position |
| Clip thumbnail | クリップサムネイル | A representative frame near the clip IN point |
| Editing sequence | 編集シーケンス | Ordered, contiguous clips that become the output |
| Fast mode | 高速 | Video stream copy where compatible; cut may follow keyframe constraints and audio may require conversion |
| Accurate mode | フレーム正確 | Timestamp-prioritized export; re-encode when required |
| Proxy | プロキシ | Temporary preview media; never the final export source |

Names in source code may follow language conventions, but user-visible behavior and documentation must map back to these concepts.

## 3. Shared workflow contract

Both platforms must support the same primary flow:

1. Open or drop one local source file.
2. Inspect streams and determine preview compatibility.
3. Provide direct preview or a proxy path without changing the source.
4. Play, pause, scrub, jump, and step one displayed frame in either direction.
5. Set a draft IN point and OUT point and add the subclip to the editing sequence.
6. Display, trim, remove, drag-reorder, and preview retained clips.
7. Continuously preview the editing sequence while skipping unused source ranges.
8. Choose Fast or Accurate export.
9. Join the edit list into a new MP4 with progress, cancellation, and a recoverable error state.
10. Move by one frame, ten frames, or five seconds using equivalent visible controls and platform-appropriate shortcuts.
11. Display the same normalized keyframe PTS data and per-segment Fast candidate boundaries on Mac and Windows.
12. Allow explicit audio-stream selection when multiple source audio streams exist.
13. Validate video, chosen audio, segment order, and combined duration before presenting an export as complete.
14. Distinguish a valid uncommitted IN/OUT draft from retained clips by both fill semantics and boundary style; committing changes the draft presentation into the retained presentation.
15. Run keyframe inspection without a modal panel once playable media is visible, while keeping its state visible near the source timeline.
16. Provide J/K/L shuttle semantics and continuous scrubbing with a precise final seek. Native playback mechanisms may differ, but direction, bounded speed changes, stop behavior, and displayed position must agree.

The first Mac and Windows releases may differ visually, but neither should introduce a different editing model.

## 4. Shared media contract

### Inputs

Priority containers are MP4, MOV, M2TS, and MTS. Stream inspection, not the filename extension alone, decides the processing path.

Priority video codecs are H.264, HEVC, and MPEG-2 Video. Priority audio codecs are AAC, AC-3, E-AC-3, and PCM.

### Output

- Container: MP4.
- Accurate default video: H.264.
- Accurate optional video: HEVC.
- Accurate default audio: AAC.
- Resolution and frame rate: preserve source by default when technically valid.
- Metadata: preserve aspect ratio, rotation, and color information when supported and valid.

Platform hardware encoders may produce different binary output. Behavioral parity means matching the requested range and documented codec/container settings within agreed tolerances, not identical bytes.

## 5. Time and range contract

- The canonical internal unit is the source presentation timestamp, represented without assuming a constant frame duration.
- Project interchange must not store only a human-readable frame number.
- A range is valid only when `outTimestamp > inTimestamp`.
- A clip has a stable identifier and exactly one valid source range.
- A clip name remains attached to the same clip after trimming or reordering. Sequence position is communicated by placement, not a redundant position number on the card.
- An editing sequence preserves explicit output order. Source ranges in one sequence must not overlap, even when output order differs from source chronology.
- Draft IN/OUT values are not exported until added to or used to trim a clip in the editing sequence.
- The current editing sequence is contiguous: moving a clip changes order but does not create a gap, overlap, or track.
- The UI may display `HH:MM:SS:FF` for constant-frame-rate sources.
- For variable-frame-rate sources, frame display is informational; saved edit boundaries remain timestamp-based.
- Seeking and range validation clamp positions to `[0, sourceDuration]`.

If a shared project JSON format is added, timestamps should be represented as an integer value plus integer timescale to avoid floating-point drift:

```json
{
  "schemaVersion": 1,
  "source": {
    "pathHint": "example.m2ts",
    "sizeBytes": 123456789,
    "modifiedAt": "2026-08-14T00:00:00Z"
  },
  "segments": [
    {
      "id": "intro",
      "in": { "value": 60000, "timescale": 60000 },
      "out": { "value": 660000, "timescale": 60000 }
    }
  ],
  "exportMode": "fast"
}
```

The sample is a compatibility direction, not a frozen schema until the project-save feature is accepted.

## 6. Export behavior contract

### Fast mode

- Copy compatible streams without video re-encoding.
- Convert audio only when required for MP4 compatibility.
- Explain before export that boundaries may move to a nearby keyframe.
- Never claim frame accuracy when stream-copy constraints prevent it.
- For multiple ranges, create a candidate for each segment and join the resulting compatible temporary segments without video re-encoding.

### Accurate mode

- Prioritize requested source timestamps.
- Re-encode video when necessary.
- Use a platform hardware encoder when it is available and produces a compliant result.
- Default to H.264/AAC MP4.
- For multiple ranges, reset timestamps for each segment and join them in edit-list order with continuous output timestamps.

### Shared safety invariants

- Never modify, rename, move, or delete the source.
- Never allow the source path as the output path.
- Write to an incomplete temporary destination and finalize only on success.
- A failed or cancelled export must not look like a completed file.
- Process arguments must be passed as an argument array, not interpolated into a shell command.
- Paths with spaces, Japanese text, quotes, and emoji must work.

## 7. Proxy and cache contract

- Proxy media exists only to improve preview and navigation.
- Final output is generated from source media.
- A proxy cache key must detect source replacement or modification.
- The UI must show proxy/cache location and disk usage.
- Users must be able to remove generated data without affecting source or completed exports.

Default cache locations are platform-specific. Cache identity and cleanup outcomes are shared behavior.

## 8. Shared error categories

Implementations should map platform-specific errors into these user-facing categories:

| Category | Expected user action |
|---|---|
| Source unreadable | Check access, file existence, or damage |
| Unsupported streams | Review detected codecs or create a proxy |
| Proxy failed | View diagnostics, free space, or retry |
| Invalid range | Put IN before OUT |
| Output conflict | Choose another path or explicitly replace |
| Insufficient space | Free space or choose another destination |
| Export cancelled | Retry when ready; no completed-looking file remains |
| Export failed | View a concise error and optional detailed diagnostics |

## 9. Keyboard behavior

The functional shortcuts should match where platform conventions do not conflict:

- Space: play/pause.
- Left/Right Arrow while editing: one frame backward/forward.
- `I`: set IN.
- `O`: set OUT.
- Open and Save/Export use the platform's conventional modifier key.

Every shortcut must have a visible control; keyboard use is never mandatory.

## 10. Cross-platform acceptance matrix

Mac and Windows builds should run the same behavioral scenarios using equivalent test media:

1. Open and navigate a 5 GB or larger H.264 MP4 without memory scaling to file size.
2. Open and navigate a 4K HEVC MP4/MOV.
3. Set a range with keyboard commands and export it in Fast mode.
4. Export the same range in Accurate mode and measure actual boundaries.
5. Handle 1080i M2TS with AC-3 audio through direct preview or proxy and produce synchronized H.264/AAC MP4.
6. Cancel proxy creation and export without freezing the app or leaving a completed-looking file.
7. Prevent source overwrite.
8. Show a recoverable error for broken or unsupported media.
9. Repeat key scenarios with paths containing spaces, Japanese text, quotes, and emoji.
10. Create three retained ranges, reorder them, continuously preview them, and export one combined MP4 in both modes.
11. Select a non-default source audio stream and verify the combined output uses it.

Each platform records open-to-usable time, seek time, frame-step time, peak memory, export speed, A/V sync, and cut-boundary difference. Results may differ, but failures and accepted tolerances must be documented.

## 11. Coordination rule

When the Mac implementation changes shared behavior, update this contract in the same change. Mac-only implementation changes stay in Mac documentation. Windows-specific constraints should be proposed against this contract rather than copied into Mac code.
