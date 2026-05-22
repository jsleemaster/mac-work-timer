#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/build/Mac Work Timer.app"
BIN_PATH="$ROOT_DIR/.build/release/MacWorkTimer"

cd "$ROOT_DIR"
swift build -c release --product MacWorkTimer

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/MacWorkTimer"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
if [ -d "$ROOT_DIR/Resources/Images" ]; then
  cp -R "$ROOT_DIR/Resources/Images" "$APP_DIR/Contents/Resources/Images"
fi
chmod +x "$APP_DIR/Contents/MacOS/MacWorkTimer"

/usr/bin/plutil -lint "$APP_DIR/Contents/Info.plist" >/dev/null

CODE_SIGN_IDENTITY="${MAC_WORK_TIMER_CODESIGN_IDENTITY:--}"
/usr/bin/codesign --force --deep --sign "$CODE_SIGN_IDENTITY" "$APP_DIR" >/dev/null

echo "$APP_DIR"
