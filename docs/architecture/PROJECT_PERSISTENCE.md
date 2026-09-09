# Project persistence architecture

- Status: Shared schema accepted; macOS and Windows implementations available for human check
- Updated: 2026-08-28
- Contract: `contracts/project.schema.json`

## Purpose and boundary

A `.trimlet` file records non-destructive edit decisions for one source video. It does not contain media, proxy data, thumbnails, rendered output, or an absolute machine-local path. macOS and Windows share the serialized meaning while using native file dialogs, media APIs, and state containers.

## Version 1 document

The root contains `schemaVersion`, `source`, `editList`, and `settings`.

- `source`: display filename, portable relative path, optional byte size, and optional ISO-8601 modification time.
- `editList.segments`: ordered UUID, optional name, and canonical integer `in`/`out` timestamps.
- `settings`: `fast` or `accurate`, plus optional selected audio stream metadata.

Timestamp comparisons use rational value, so equivalent fractions represent the same source position. Serialization is nevertheless lossless: decoding and re-encoding an unchanged project preserves the original integer `value` and `timescale` pair. This keeps native implementations from rewriting each other's documents merely because they choose different internal normalization strategies.

`contracts/project.schema.json` is normative. `contracts/fixtures/project-cases.json` provides valid and rejected examples. Version 1 is a closed document: unknown fields are rejected instead of silently discarded. Any added or removed persisted field, changed meaning, or incompatible identifier/timestamp rule requires a new schema version and migration decision.

## Source resolution

1. Resolve `source.pathHint` relative to the project document.
2. If the file exists and size/modification hints match, open it automatically.
3. If the candidate exists but differs, warn and require an explicit Use or Relink choice.
4. If missing, request a replacement source with the native Open dialog.
5. Validate every saved OUT against the loaded source duration.
6. A relinked reference or missing selected audio stream marks the project dirty until saved.

The identity hints catch ordinary moves and replacements; they are not security credentials and do not claim content equality. A future content hash may be added as an optional field after large-file cost is measured.

## Atomicity and failure behavior

Encode and validate the complete document before writing, enforce the same 8 MiB limit on output, and write atomically to the selected destination. Decode untrusted project data with an 8 MiB pre-read limit, a closed known-field set, checked timestamp values/timescales, schema version, unique UUIDs, valid ranges, and non-overlap validation. Failure leaves the source unchanged and displays a recoverable error.

Opening another source/project and terminating the app use Save, Don't Save, and Cancel. Saving is disabled while media is loading or exporting.

## macOS implementation

- `TrimletProject.swift`: project models, validation, codec, relative path capture, and source identity comparison.
- `PlayerController.swift`: dirty state, save construction, deferred restoration after playable media loads, range validation, thumbnail regeneration.
- `ContentView.swift`: native Open/Save As dialogs, project menu, mismatch/relink prompts, and replacement confirmation.
- `Info.plist`: `.trimlet` document type declaration.

## Explicitly session-only

Windows implements the same document via `TrimletProject`, `ProjectStore`, and
native project commands in `MainPage.Project.cs`. See [Windows verification and
cross-platform follow-up](../../apps/windows/BUILD10_PARITY_RETURN.md).

- draft IN/OUT and trim-editor mode;
- current playhead and playback/shuttle state;
- thumbnails and preview proxies;
- undo/redo stacks and current card selection;
- keyframe/frame indexes, progress state, logs, and export destinations.

Persist these only after a separate product decision defines their cross-platform meaning and migration cost.
