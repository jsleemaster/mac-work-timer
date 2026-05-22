# Mac Work Timer

macOS menu bar app for tracking a 9-hour workday from the GW attendance check-in record. It is read-only toward the configured GW/Bizbox server: it never submits attendance records.

## What it does

- Reads the GW check-in record after web login.
- Calculates the target time as check-in + 9 hours using wall-clock elapsed time.
- Shows remaining time in the menu bar and a normal SwiftUI window.
- Stores app state in `~/Library/Application Support/Mac Work Timer/state.json`.
- Stores GW credentials only in macOS Keychain.
- Tries read-only GW login/status refresh with `URLSession`; if 2FA or policy blocks it, opens GW in an embedded `WKWebView`.
- Can register itself as a login item from Settings.

## Build

```bash
cd mac-work-timer
swift test
scripts/build_app.sh
open "build/Mac Work Timer.app"
```

## Demo distribution

This repository can be distributed as a demo app by attaching a zipped `.app` bundle to a GitHub Release. That is enough for other macOS users to download and try the menu bar timer, floating pet, and local UI behavior.

The demo build is not a production distribution channel. Unless the app is signed with an Apple Developer ID certificate and notarized by Apple, macOS Gatekeeper may show a security warning or require the user to approve the app manually in System Settings.

The public demo intentionally uses `https://gw.example.com` as the default GW address. Real GW/Bizbox integration should be configured privately per user or organization, and this app should remain read-only: it must not submit attendance records, manipulate security apps, or bypass two-factor authentication.

Recommended release path:

1. Build the app with `scripts/build_app.sh`.
2. Compress `build/Mac Work Timer.app` into a zip file.
3. Create a GitHub Release such as `v0.1.0`.
4. Upload the zip as the release asset.
5. For broader distribution, add Developer ID signing and Apple notarization before publishing the release.

## GW inspection

Read-only login-page inspection uses Playwright, matching the workspace rule for browser debugging:

```bash
cd mac-work-timer
npm exec --yes --package=playwright -- playwright install chromium
npm exec --yes --package=playwright -- node scripts/inspect_gw_login.mjs https://gw.example.com/gw/bizbox.do
```

Use this only to inspect forms, navigation, and read-only attendance pages. Do not call attendance write endpoints from this app.
