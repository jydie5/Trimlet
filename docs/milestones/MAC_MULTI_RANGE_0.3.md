# Mac multi-range milestone 0.3

- Status: Accepted for implementation
- Defined: 2026-08-24
- Goal: Reach the next human check with useful multi-cut editing while preserving Trimlet's focused single-source product.

## Outcome

A user can open one source video, collect multiple retained ranges, arrange their output order, continuously preview the sequence, select an audio stream, and export one validated MP4 in Accurate or Fast mode.

This milestone does not attempt to become a general non-linear editor. It adds no second source, tracks, transitions, titles, effects, independent audio editing, or plug-in system.

## Required user behavior

1. Mark draft IN and OUT positions.
2. Add the draft as a retained segment.
3. Select a segment to load its boundaries, update it, remove it, or move it earlier/later in output order.
4. Undo and redo edit-list changes.
5. See retained segments, the active draft, playhead, keyframes, and Fast candidates on one timeline.
6. Preview the draft, one selected segment, or all retained segments continuously.
7. Select the source audio stream when more than one exists.
8. Export all retained segments to one destination.

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
