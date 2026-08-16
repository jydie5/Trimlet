# Trimlet shared contracts

This directory contains platform-neutral inputs used to keep the native macOS and Windows implementations behaviorally aligned.

## Stability policy

- Every JSON document contains `schemaVersion`.
- Additive optional fields may be introduced without changing the major schema version.
- Removing a field, changing its meaning, or changing an identifier requires a schema-version change and migration note.
- Integer timestamp value plus integer timescale is canonical. Floating-point seconds are display or diagnostic values only.
- Fixtures describe observable behavior, not Swift or C# implementation details.

## Files

- `error-codes.json`: canonical cross-platform error identifiers and meanings.
- `export-plan.schema.json`: interchange shape for an export plan.
- `fixtures/export-plan-cases.json`: initial contract cases both implementations must pass.

Run `scripts/validate-contracts.sh` on macOS/Linux or `scripts/validate-contracts.ps1` on Windows.
