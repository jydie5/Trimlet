# Windows to Mac parity audit — 2026-08-28

## Baseline and result

The audited baseline is macOS `v0.3.0-beta.1`, defined by `MAC_MULTI_RANGE_0.3.md`, `PLATFORM_CONTRACT.md`, and the Windows handover. The Windows source now implements every required user behavior and export policy in that baseline with native WinUI and Windows media choices.

## Requirement evidence

| Mac baseline behavior | Windows evidence |
| --- | --- |
| Visible IN → OUT → Add flow and cleared draft | WinUI range state plus developer UI add check |
| Selection separate from explicit Trim Edit | Dedicated handlers and developer UI trim-update check |
| Stable identity, editable name, thumbnail, IN–OUT | Immutable edit-list tests, FFmpeg thumbnails, rename UI check |
| Drag and earlier/later reorder | ListView reorder plus edit-list move tests and earlier-button UI check |
| Delete and Undo/Redo | Edit-list mutation tests and developer Undo/Redo check |
| Draft, retained ranges, playhead, keyframes, Fast candidates | Source timeline rendering and 1280×900 visual check |
| Draft, selected clip, and continuous sequence preview | Preview state machine and developer sequence-preview check |
| Multi-audio selection | Two-audio synthetic source; non-default stream verified in both output modes |
| One combined Accurate export | Three reordered segments; sampled colors, duration, audio, validation, cleanup |
| One combined Fast export | Per-segment keyframe candidates, stream-copy concat, sampled colors, audio, validation |
| Proxy fallback without changing source identity | M2TS/AC-3 generated source, proxy validation/reuse, source hash check, UI playback check |
| Actual-frame navigation | Irregular ffprobe timestamps, index tests, generated VFR check, UI status and stepping check |

## Verification boundary

The developer gate covers code, generated media, and focused UI behavior. The remaining work in `apps/windows/HUMAN_CHECK.md` is representative-machine release coverage: long or damaged media, HDR/interlace breadth, cancellation timing, language switching, packaging, signing, and clean-machine validation. These do not represent a missing behavior from the accepted Mac Beta milestone.
