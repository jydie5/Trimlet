#!/bin/sh

set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

python3 - "$project_dir" <<'PY'
import json
import pathlib
import sys
import uuid

root = pathlib.Path(sys.argv[1])
errors = json.loads((root / "contracts/error-codes.json").read_text())
schema = json.loads((root / "contracts/export-plan.schema.json").read_text())
fixtures = json.loads((root / "contracts/fixtures/export-plan-cases.json").read_text())
edit_schema = json.loads((root / "contracts/edit-list.schema.json").read_text())
edit_fixtures = json.loads((root / "contracts/fixtures/edit-list-cases.json").read_text())
project_schema = json.loads((root / "contracts/project.schema.json").read_text())
project_fixtures = json.loads((root / "contracts/fixtures/project-cases.json").read_text())

assert errors["schemaVersion"] == 1
ids = [item["id"] for item in errors["errors"]]
assert ids and len(ids) == len(set(ids))
assert schema["properties"]["schemaVersion"]["const"] == 1
assert fixtures["schemaVersion"] == 1
assert edit_schema["properties"]["schemaVersion"]["const"] == 1
assert edit_fixtures["schemaVersion"] == 1
assert project_schema["properties"]["schemaVersion"]["const"] == 1
assert project_fixtures["schemaVersion"] == 1

def has_only_keys(value, allowed):
    return isinstance(value, dict) and set(value).issubset(allowed)

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

edit_case_ids = set()
for case in edit_fixtures["cases"]:
    assert case["id"] not in edit_case_ids
    edit_case_ids.add(case["id"])
    segments = case["input"]["segments"]
    segment_ids = [segment["id"] for segment in segments]
    assert len(segment_ids) == len(set(segment_ids))
    valid_ranges = True
    has_overlap = False
    normalized = []
    for segment in segments:
        start = segment["in"]
        end = segment["out"]
        if start["value"] * end["timescale"] >= end["value"] * start["timescale"]:
            valid_ranges = False
        normalized.append((
            start["value"] / start["timescale"],
            end["value"] / end["timescale"],
        ))
    for index, first in enumerate(normalized):
        for second in normalized[index + 1:]:
            if first[0] < second[1] and second[0] < first[1]:
                has_overlap = True
    assert case["valid"] == (valid_ranges and not has_overlap)

project_case_ids = set()
for case in project_fixtures["cases"]:
    assert case["id"] not in project_case_ids
    project_case_ids.add(case["id"])
    document = case["input"]
    source = document.get("source", {})
    settings = document.get("settings", {})
    path_hint = source.get("pathHint", "")
    has_drive_prefix = len(path_hint) >= 2 and path_hint[1] == ":"
    size_bytes = source.get("sizeBytes")
    audio = settings.get("audio")
    valid = (
        document.get("schemaVersion") == 1
        and has_only_keys(document, {"schemaVersion", "source", "editList", "settings"})
        and has_only_keys(source, {"fileName", "pathHint", "sizeBytes", "modifiedAt"})
        and has_only_keys(document.get("editList"), {"segments"})
        and has_only_keys(settings, {"exportMode", "audio"})
        and bool(source.get("fileName"))
        and bool(path_hint)
        and not path_hint.startswith("/")
        and not has_drive_prefix
        and "\\" not in path_hint
        and settings.get("exportMode") in {"fast", "accurate"}
        and (
            size_bytes is None
            or type(size_bytes) is int and 0 <= size_bytes <= 9_223_372_036_854_775_807
        )
        and (
            audio is None
            or isinstance(audio, dict)
            and has_only_keys(audio, {"streamIndex", "codecName", "language", "title"})
            and type(audio.get("streamIndex")) is int
            and 0 <= audio["streamIndex"] <= 2_147_483_647
        )
    )
    segments = document.get("editList", {}).get("segments", [])
    identifiers = [segment.get("id") for segment in segments]
    valid = valid and len(identifiers) == len(set(identifiers))
    try:
        for identifier in identifiers:
            uuid.UUID(identifier)
    except (AttributeError, TypeError, ValueError):
        valid = False
    ranges = []
    for segment in segments:
        start = segment["in"]
        end = segment["out"]
        if not has_only_keys(segment, {"id", "in", "out", "name"}):
            valid = False
        if not has_only_keys(start, {"value", "timescale"}) or not has_only_keys(
            end, {"value", "timescale"}
        ):
            valid = False
        stamps_are_bounded_integers = all(
            type(stamp.get(key)) is int
            for stamp in (start, end)
            for key in ("value", "timescale")
        )
        if not stamps_are_bounded_integers:
            valid = False
            continue
        if (
            start["value"] < 0
            or end["value"] < 0
            or start["value"] > 9_223_372_036_854_775_807
            or end["value"] > 9_223_372_036_854_775_807
            or start["timescale"] <= 0
            or end["timescale"] <= 0
            or start["timescale"] > 2_147_483_647
            or end["timescale"] > 2_147_483_647
        ):
            valid = False
            continue
        if start["value"] * end["timescale"] >= end["value"] * start["timescale"]:
            valid = False
        ranges.append((start, end))
    for index, first in enumerate(ranges):
        for second in ranges[index + 1:]:
            if (
                first[0]["value"] * second[1]["timescale"]
                < second[1]["value"] * first[0]["timescale"]
                and second[0]["value"] * first[1]["timescale"]
                < first[1]["value"] * second[0]["timescale"]
            ):
                valid = False
    assert case["valid"] == valid

print(
    f"Shared contracts: {len(case_ids)} export cases, "
    f"{len(edit_case_ids)} edit-list cases, {len(project_case_ids)} project cases, "
    f"and {len(ids)} error codes passed"
)
PY
