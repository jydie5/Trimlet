# Trimlet shared contracts

The build 10 source-timeline interaction is specified separately in
[`docs/TIMELINE_INTERACTION_2026-09-09.md`](../docs/TIMELINE_INTERACTION_2026-09-09.md).
It changes presentation and pointer semantics only; it does not add a persisted
field or change the schema.

This directory contains platform-neutral inputs used to keep the native macOS and Windows implementations behaviorally aligned.

## Stability policy

- Every JSON document contains `schemaVersion`.
- Published schema versions are closed documents: unknown fields are rejected so one native app cannot silently erase another app's data. Adding or removing a persisted field, changing its meaning, or changing an identifier requires a schema-version change and migration note.
- Integer timestamp value plus integer timescale is canonical. Floating-point seconds are display or diagnostic values only.
- Readers compare equivalent rational timestamps by value but preserve the stored `value`/`timescale` pair when writing an unchanged project; opening and saving must not silently rewrite shared fixture timestamps.
- Fixtures describe observable behavior, not Swift or C# implementation details.

## Files

- `error-codes.json`: canonical cross-platform error identifiers and meanings.
- `export-plan.schema.json`: interchange shape for an export plan.
- `fixtures/export-plan-cases.json`: initial contract cases both implementations must pass.
- `edit-list.schema.json`: ordered retained ranges for multi-range editing.
- `fixtures/edit-list-cases.json`: valid reordered and invalid overlapping edit-list cases.
- `project.schema.json`: portable `.trimlet` project document shared by macOS and Windows.
- `fixtures/project-cases.json`: valid round-trip and rejected project cases.

## Project portability rules

- `source.pathHint` uses `/` separators and is relative to the `.trimlet` file. It may contain `..` components.
- `source.sizeBytes` and `source.modifiedAt` are identity hints. A mismatch requires an explicit relink/continue decision; neither field is a security boundary.
- `editList.segments` order is the output order. Segment IDs are unique UUIDs.
- Draft IN/OUT state, playhead, thumbnails, proxies, undo history, and generated output paths are not project data.

Run `scripts/validate-contracts.sh` on macOS/Linux or `scripts/validate-contracts.ps1` on Windows.
