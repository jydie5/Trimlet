# Mac project persistence milestone 0.4

- Status: Implemented; human check pending
- Updated: 2026-08-28
- Goal: Resume useful multi-range work without turning Trimlet into a media-library application.

## Delivered

- Portable schema-versioned `.trimlet` JSON contract and fixtures.
- Project Open, Save, and Save As with conventional macOS shortcuts.
- Persistent clip IDs, names, ordered ranges, export mode, and selected audio stream.
- Relative source reference with size/modification identity hints.
- Missing/changed source relink flow and validation against loaded duration.
- Unsaved marker and Save/Don't Save/Cancel before replacement or termination.
- Atomic writes, checked timestamp decoding, duplicate-ID and invalid-range rejection.
- Recreated clip thumbnails after restore; proxies and thumbnails stay out of project data.

## Verification completed

- macOS debug build.
- Core checks for lossless JSON round-trip, platform-neutral keys, unreduced timestamp-pair preservation, schema rejection, invalid timestamps and metadata, duplicate IDs, relative paths, and identity matching.
- Twelve shared contract fixtures are consumed by both the POSIX/PowerShell validators and the production Mac project codec.
- Existing generated-media Fast/Accurate integration checks.

## Requirement evidence

| Requirement | Automated/developer evidence | Remaining human evidence |
|---|---|---|
| FR-080 save complete persistent state | Production codec round-trip and exact shared-fixture re-encode; `PlayerController.saveProject` constructs source, ordered clips, settings, and audio | Save a three-clip edited project |
| FR-081 restore without source mutation | Deferred restore validates and reapplies order/name/timestamp/mode/audio; generated-media integration confirms source immutability | Quit, reopen, and compare visible state |
| FR-082 relative portable reference | Unicode/space/`..` capture-resolution checks; absolute POSIX/drive paths rejected | Inspect one saved document if desired |
| FR-083 identity and explicit relink | Size/mtime capture and match/mismatch core checks; native changed/missing-source branches | Move and replace the test source |
| FR-084 range validation and dirty relink | Restore validates every OUT against loaded duration; changed reference/audio fallback sets dirty | Confirm mismatch cannot be accepted silently |
| FR-085 atomic and invalid-data failure | Atomic disk round-trip; twelve fixtures cover portable complete/minimal projects plus schema, unknown fields, timestamp, UUID, overlap, source, and audio failures; 8 MiB pre-read/decode and encode limits are checked | Confirm recoverable error presentation |
| FR-086 unsaved decisions | Window-close guard, Command-Q delegate, pre-replacement confirmation, and no forced termination in `run-poc.command` | Exercise Save / Don't Save / Cancel on close, quit, and replacement |
| FR-087 session-only data exclusion | Exact emitted JSON key-set/fixture round-trip and closed JSON schema; models contain no draft/playhead/cache/history/output fields | Optional text inspection |
| FR-088 one shared native contract | Mac production codec consumes the shared fixtures; shell and PowerShell validators share them | Windows implementation follows the handover after Mac acceptance |

## Human gate

Follow the project section in `docs/HUMAN_CHECK.md`. The milestone is not release-accepted until save, quit, reopen, relink, mismatch warning, and unsaved cancellation are exercised in the built app.

After acceptance, capture one Mac 0.4 screenshot using generated/non-personal media with the project name, unsaved marker, source timeline, and editing sequence visible. Add it to both root READMEs alongside the existing Windows image before publishing the 0.4 release; do not reuse a screenshot containing personal source media or local paths.

## Windows follow-up

Windows must implement the same document contract using WinUI-native pickers and C# models. It must not copy Swift code or store Windows absolute paths. See `apps/windows/PROJECT_PERSISTENCE_HANDOVER.md`.
