# Mac multi-range milestone 0.3

- Status: Implemented; focused interaction check accepted for `v0.3.0-beta.1` on 2026-08-28
- Defined: 2026-08-24
- Goal: Reach the next human check with useful multi-cut editing while preserving Trimlet's focused single-source product.

## Outcome

A user can open one source video, collect multiple retained ranges, arrange their output order, continuously preview the sequence, select an audio stream, and export one validated MP4 in Accurate or Fast mode.

This milestone does not attempt to become a general non-linear editor. It adds no second source, tracks, transitions, titles, effects, independent audio editing, or plug-in system.

## Required user behavior

1. Follow the visible `1 IN → 2 OUT → 3 Add to Sequence` flow to create a subclip.
2. See the editor clear after the clip appears in the always-visible editing sequence.
3. Select a clip without changing the active IN/OUT draft. Enter the distinct trim state only through its explicit `Trim Edit` action, then apply the trim; removal and reordering operate directly on selection.
4. Drag clips directly to rearrange the editing sequence; use earlier/later buttons as an equivalent alternative.
5. Identify each clip by its representative thumbnail, editable name, and IN–OUT range rather than a position number.
6. Undo and redo sequence changes.
7. See retained clips, the active draft, playhead, keyframes, and Fast candidates on the source timeline.
8. Preview the draft, one selected clip, or the complete sequence continuously.
9. Select the source audio stream when more than one exists.
10. Export all retained clips to one destination.

## Export policy

### Accurate

- Re-encode each retained segment with the same VideoToolbox H.264/AAC settings for this milestone.
- Reset segment timestamps and concatenate encoded temporary segments in edit-list order.
- Validate the final video, selected audio, and duration before finalization.

### Fast

- Compute and show a keyframe-expanded candidate per segment.
- Stream-copy video for each candidate and convert audio only when MP4 compatibility requires it.
- Concatenate compatible temporary segments in edit-list order without video re-encoding.
- If no valid candidate exists for any segment, disable Fast export and direct the user to Accurate.

## Acceptance gate

- Core checks cover integer timestamps, edit-list validation, ordering, overlap rejection, mutations, undo snapshots, per-segment Fast candidates, and multi-stage FFmpeg arguments.
- Generated-media integration covers three ranges in chronological and reordered output sequences where a compatible local FFmpeg is available.
- Swift build and existing shared-contract checks pass.
- The human-check guide contains a repeatable multi-range script and known limitations.
