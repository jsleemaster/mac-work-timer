# Mac Work Timer

macOS menu bar app for tracking a 9-hour workday from the GW attendance check-in record. It is read-only toward the configured GW/Bizbox server: it never submits attendance records.

## What it does

- Reads the GW check-in record after web login.
- Calculates the target time as check-in + 9 hours using wall-clock elapsed time.
- Shows remaining time in the menu bar and a normal SwiftUI window.
- Shows local Codex/Claude 5-hour usage remaining when available.
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

## Pet assets

The floating pet supports a daily capsule reveal. Keep all public assets original; do not ship trademarked ball designs, official characters, or copied game artwork.

Optional custom images:

- `Resources/Images/capsule-closed.png`: closed capsule reference, transparent PNG.
- `Resources/Images/capsule-open.png`: open capsule reference, transparent PNG.
- `Resources/Images/PetFrames/capsule-idle-0.png` ... `capsule-idle-5.png`: closed idle animation.
- `Resources/Images/PetFrames/capsule-shake-0.png` ... `capsule-shake-7.png`: shake animation.
- `Resources/Images/PetFrames/capsule-open-0.png` ... `capsule-open-7.png`: opening animation.
- `Resources/Images/PetFrames/pet-<id>-idle-0.png` ... `pet-<id>-idle-5.png`: registered pet idle frames.

If these images are missing, the app falls back to its built-in SwiftUI capsule and default pet frames.

Local-only personal pet images can also be stored outside the repository at `~/MacWorkTimerLocalPets`:

- `stage-1.png`
- `stage-2.png`
- `stage-3.png`
- `sources.json`

When all three PNG files exist, the app treats them as one local-only evolving pet and keeps those files out of GitHub and public release builds.

## AI usage indicator

The pet label and menu dropdown can show Codex and Claude 5-hour usage remaining:

- Codex is read from local `~/.codex/sessions/**/*.jsonl` rate-limit events.
- Claude is read from `~/Library/Application Support/Mac Work Timer/agent-usage/claude.json` when a Claude Code status line bridge writes it.
- If the bridge is not configured, the app also checks `~/.claude/plugins/claude-hud/.usage-cache.json` and marks stale values as waiting.

The app only reads rate-limit fields such as percentage and reset time. It does not store prompts, responses, API keys, tokens, or environment variables.

Optional Claude Code bridge:

```bash
scripts/claude_statusline_bridge.js
```

The bridge reads Claude Code status-line JSON from stdin and writes only the five-hour usage percentage/reset timestamp to the app support folder. If you already use a status-line command, call the bridge with `--forward "<existing command>"` so the existing status line still renders.

## GW inspection

Read-only login-page inspection uses Playwright, matching the workspace rule for browser debugging:

```bash
cd mac-work-timer
npm exec --yes --package=playwright -- playwright install chromium
npm exec --yes --package=playwright -- node scripts/inspect_gw_login.mjs https://gw.example.com/gw/bizbox.do
```

Use this only to inspect forms, navigation, and read-only attendance pages. Do not call attendance write endpoints from this app.
