#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
MAC_PROJECT_DIR="$PROJECT_DIR/apps/macos"
APP_DIR="$PROJECT_DIR/dist/Trimlet.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

cd "$MAC_PROJECT_DIR"

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

mkdir -p "$MACOS_DIR"
cp "$BIN_DIR/Trimlet" "$MACOS_DIR/Trimlet"
cp "$MAC_PROJECT_DIR/support/Info.plist" "$CONTENTS_DIR/Info.plist"

codesign --force --deep --sign - "$APP_DIR"

echo "$APP_DIR"
