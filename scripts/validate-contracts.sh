#!/bin/sh

set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

python3 - "$project_dir" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
errors = json.loads((root / "contracts/error-codes.json").read_text())
schema = json.loads((root / "contracts/export-plan.schema.json").read_text())
fixtures = json.loads((root / "contracts/fixtures/export-plan-cases.json").read_text())

assert errors["schemaVersion"] == 1
ids = [item["id"] for item in errors["errors"]]
assert ids and len(ids) == len(set(ids))
assert schema["properties"]["schemaVersion"]["const"] == 1
assert fixtures["schemaVersion"] == 1

case_ids = set()
for case in fixtures["cases"]:
    assert case["id"] not in case_ids
    case_ids.add(case["id"])
    plan = case["input"]
    assert plan["schemaVersion"] == 1
    assert plan["mode"] in {"fast", "accurate"}
    assert plan["output"]["container"] == "mp4"
    for boundary in ("in", "out"):
        stamp = plan["range"][boundary]
        assert isinstance(stamp["value"], int) and stamp["value"] >= 0
        assert isinstance(stamp["timescale"], int) and stamp["timescale"] > 0
    start = plan["range"]["in"]
    end = plan["range"]["out"]
    assert start["value"] * end["timescale"] < end["value"] * start["timescale"]

print(f"Shared contracts: {len(case_ids)} fixture cases and {len(ids)} error codes passed")
PY
