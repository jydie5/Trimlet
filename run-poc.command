#!/bin/zsh

set -euo pipefail

PROJECT_DIR="${0:A:h}"

if pgrep -x Trimlet >/dev/null 2>&1; then
    osascript -e 'tell application id "dev.trimlet.poc" to quit' >/dev/null 2>&1 || true
    for _ in {1..20}; do
        pgrep -x Trimlet >/dev/null 2>&1 || break
        sleep 0.1
    done
    if pgrep -x Trimlet >/dev/null 2>&1; then
        pkill -TERM -x Trimlet
    fi
fi

"$PROJECT_DIR/scripts/build-poc-app.sh"
open "$PROJECT_DIR/dist/Trimlet.app"
