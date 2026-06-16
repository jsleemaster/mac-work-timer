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

if [ -n "${MAC_WORK_TIMER_CODESIGN_IDENTITY:-}" ]; then
  CODE_SIGN_IDENTITY="$MAC_WORK_TIMER_CODESIGN_IDENTITY"
else
  CODE_SIGN_IDENTITY="$(
    /usr/bin/security find-identity -p codesigning -v 2>/dev/null \
      | /usr/bin/awk '/Apple Development:/ { print $2; exit }'
  )"
  CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
fi

/usr/bin/codesign --force --deep --sign "$CODE_SIGN_IDENTITY" "$APP_DIR" >/dev/null

echo "$APP_DIR"
