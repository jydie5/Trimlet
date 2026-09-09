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
# Replace the inode rather than truncating an executable a previous app process
# may still have mapped. The running process keeps its old build until restart.
STAGED_BINARY="$(mktemp "$MACOS_DIR/.Trimlet.XXXXXX")"
cp "$BIN_DIR/Trimlet" "$STAGED_BINARY"
# mktemp creates mode 0600; copying into that existing file retains its mode.
# Restore executable permissions before installing and signing the bundle.
chmod 755 "$STAGED_BINARY"
mv -f "$STAGED_BINARY" "$MACOS_DIR/Trimlet"
cp "$MAC_PROJECT_DIR/support/Info.plist" "$CONTENTS_DIR/Info.plist"

codesign --force --deep --sign - "$APP_DIR"
test -x "$MACOS_DIR/Trimlet"
codesign --verify --deep --strict "$APP_DIR"

echo "$APP_DIR"
