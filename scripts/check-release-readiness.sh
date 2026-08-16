#!/bin/sh

set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir"

failed=0

require_file() {
    if [ ! -s "$1" ]; then
        echo "Missing required release file: $1" >&2
        failed=1
    fi
}

require_file LICENSE
require_file README.md
require_file THIRD_PARTY_NOTICES.md
require_file SECURITY.md
require_file CONTRIBUTING.md

tracked_forbidden=$(git ls-files | grep -E '(^|/)(dist|TestMedia|Tools)/|\.(m2ts|mts)$|(^|/)ffmpeg(\.exe)?$|(^|/)ffprobe(\.exe)?$' || true)
if [ -n "$tracked_forbidden" ]; then
    echo "Forbidden generated media/tool files are tracked:" >&2
    echo "$tracked_forbidden" >&2
    failed=1
fi

scripts/validate-contracts.sh

if [ "$failed" -ne 0 ]; then
    exit 1
fi

echo "Source release readiness checks passed"
