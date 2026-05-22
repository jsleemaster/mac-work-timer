# Mac Work Timer

macOS menu bar app for tracking a 9-hour workday from the GW attendance check-in record. It is read-only toward EVAR GW/Bizbox: it never submits attendance records.

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

## GW inspection

Read-only login-page inspection uses Playwright, matching the workspace rule for browser debugging:

```bash
cd mac-work-timer
npm exec --yes --package=playwright -- playwright install chromium
npm exec --yes --package=playwright -- node scripts/inspect_gw_login.mjs
```

Use this only to inspect forms, navigation, and read-only attendance pages. Do not call attendance write endpoints from this app.
