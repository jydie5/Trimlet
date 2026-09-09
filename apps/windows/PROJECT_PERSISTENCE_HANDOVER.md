# Trimlet project persistence handover for Windows

- Prepared: 2026-08-28
- Mac state: implemented for 0.4 human check
- Windows state: implementation pending
- Normative schema: `contracts/project.schema.json`

## Required behavior

Implement native Open Project, Save, and Save As commands for `.trimlet`. Restore ordered clip identity/name/IN/OUT, Fast/Accurate mode, and selected audio. Warn before replacing or exiting a dirty project. If the source is missing, request a relink; if its size or modification time differs, require an explicit decision. Validate saved ranges against the loaded source duration.

Use WinUI/Windows App SDK conventions and localized English/Japanese resources. Do not copy `PlayerController`, Swift Codable code, AppKit dialogs, or macOS layout.

## Data mapping

| JSON | Windows model meaning |
|---|---|
| `schemaVersion` | Require integer `1`; reject unsupported versions |
| `source.fileName` | Display/expected filename |
| `source.pathHint` | `/`-separated path relative to the `.trimlet` parent; never persist a drive-qualified path |
| `source.sizeBytes` | Optional identity hint |
| `source.modifiedAt` | Optional UTC ISO-8601 identity hint; allow filesystem precision tolerance |
| `editList.segments[]` | Explicit output order |
| `id` | Unique UUID retained across reorder/trim |
| `in`, `out` | Non-negative integer value plus positive timescale; OUT exclusive |
| `name` | Optional stable user label |
| `settings.exportMode` | `fast` or `accurate` |
| `settings.audio` | Optional absolute stream index and descriptive metadata |

Draft range, playhead, thumbnail/proxy paths, Undo/Redo history, selection, analysis indexes, progress, and output destinations are not persisted.

Compare timestamp fractions by rational value, but retain their original integer pair in the loaded model. Saving an unchanged Mac-created project must not reduce or rescale its timestamps.

## Implementation order

1. Add C# schema models and decode validation; consume all project fixtures in Windows tests.
2. Add relative path capture/resolution and source identity tests, including Unicode/spaces and `..`.
3. Add atomic save with a same-directory temporary file and replacement/finalization semantics appropriate for Windows.
4. Add ViewModel dirty tracking for edit-list mutations, export mode, audio selection, relink, and audio fallback.
5. Add Open/Save/Save As and replacement/exit prompts.
6. Restore only after the source is playable and probed; validate ranges and select audio by stored stream index.
7. Regenerate thumbnails asynchronously; do not block restoration on presentation assets.
8. Run developer UI and generated-media checks, then complete the Windows human check.

Reject a project larger than 8 MiB before deserializing it, and reject an encoded Save before replacement when it exceeds the same limit. Configure the JSON reader to reject unmapped fields recursively; version 1 is closed, so silently ignoring and then erasing a field on Save is not acceptable.

## Acceptance cases

- A two-clip fixture round-trips without changing UUIDs, order, names, rational timestamps, mode, or audio index.
- Unsupported schema, unknown field, oversized document, negative timestamp, zero timescale, duplicate UUID, overlap, and out-of-source range are rejected without a crash.
- Moving project and media together preserves automatic resolution.
- Moving only media opens relink; choosing it marks the project dirty and Save updates `pathHint`.
- Replacing the hinted source triggers a warning rather than silent use.
- Save failure does not corrupt an existing project.
- Opening another item or closing with changes offers Save, Don't Save, and Cancel.

References: `docs/architecture/PROJECT_PERSISTENCE.md`, `docs/milestones/MAC_PROJECT_PERSISTENCE_0.4.md`, `docs/PLATFORM_CONTRACT.md`, and `contracts/README.md`.
