# Mac Work Timer

macOS menu bar app for tracking a 9-hour workday from the GW attendance check-in record. It is read-only toward the configured GW/Bizbox server: it never submits attendance records.

## What it does

- Reads the GW check-in record after web login.
- Calculates the target time as check-in + 9 hours using wall-clock elapsed time.
- Reads the current week's GW attendance table without submitting changes.
- Adds completed work and credited leave toward 40 hours, subtracting only the overlap with the 12:00–13:00 lunch window.
- Keeps weekly flex time available for any remaining weekday and shows `오늘 퇴근`, `이번 주 여유`, and `오늘 다 쓰면`.
- Drops holidays from the weekly 40-hour target and reports work done on them as `이번 주 초과근무`.
- Shows remaining time in the menu bar and a normal SwiftUI window.
- Shows local Codex/Claude limit status only when a 5-hour or weekly AI limit is hit.
- Stores app state in `~/Library/Application Support/Mac Work Timer/state.json`.
- Stores GW credentials only in macOS Keychain.
- Tries read-only GW login/status refresh with `URLSession`; if 2FA or policy blocks it, opens GW in an embedded `WKWebView`.
- Caches only the last successfully parsed weekly attendance rows. A failed or expired login never replaces that cache with guessed time.
- If the weekly summary is incomplete, the pet shows `주간 기록 연결하기`; click the pet and finish GW web login/2FA in the app to refresh the weekly rows.
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

## Holidays

A five-day week is not always five working days. Public holidays, substitute holidays, and company closures are treated exactly like weekends: no timer, no pet, no leave notification, and the day is removed from the weekly 40-hour target so a holiday week targets 32 hours instead.

Holidays come from two sources, merged:

- **GW**: rows whose 근태구분 contains `공휴일` (including `대체공휴일`) or `회사휴무` are read from the weekly attendance table. These appear automatically after a weekly refresh and cannot be unset locally.
- **Manual**: registered in the app for anything GW does not report, such as a company foundation day. Manual holidays are stored in `state.json` and survive a GW logout.

Manual holidays can be registered for a **past date**, not just for today — a holiday is usually noticed after the fact, and the weekly balance is recomputed from the stored holiday list on every read, so a day added afterwards is applied retroactively.

Two ways to register one:

- **Menu bar → `휴일로 표시`**: lists the current week's Monday through Friday with today marked, so any elapsed day of the week can be checked or unchecked in place. This week is the useful span because it is exactly what the 40-hour weekly balance is computed over. GW-reported holidays appear checked but disabled, since the next weekly refresh would restore them.
- **Menu bar → `설정…`** (also reachable as `다른 날짜…` inside the submenu): a date picker with an optional label, for any date outside the current week. The app runs with `.accessory` activation policy and has no application menu, so this menu item is the only way in — the SwiftUI `Settings` scene's ⌘, binding is unreachable.

Personal leave is deliberately not a holiday. `연차`, `휴가`, and half-day rows stay credited leave: the day keeps its 8-hour slot in the weekly target and the leave pays into it. A holiday instead removes the slot, which is what keeps a missing holiday row from marking the week incomplete and disabling the flex-time readout.

Work recorded on a holiday is **overtime, not flex**. It is reported separately as `이번 주 초과근무` and never folded into `이번 주 여유`, so it cannot pull `오늘 다 쓰면` earlier and be silently spent.

## AI limit indicator

The floating pet and menu dropdown show Codex and Claude only when a local 5-hour or weekly AI limit is exhausted. Normal non-limited usage is hidden to keep the timer quiet.

- Codex is read from local `~/.codex/sessions/**/*.jsonl` rate-limit events, including primary 5-hour and secondary weekly windows when present.
- Claude is read from `~/Library/Application Support/Mac Work Timer/agent-usage/claude.json` when a Claude Code status line bridge writes it.
- If the bridge is not configured, the app also checks `~/.claude/plugins/claude-hud/.usage-cache.json` and marks stale values as waiting.

When a limit is hit, the card prioritizes reset progress, for example `초기화 3%`, plus the exact reset time. The app only reads rate-limit fields such as percentage and reset time. It does not store prompts, responses, API keys, tokens, or environment variables.

Optional Claude Code bridge:

```bash
scripts/claude_statusline_bridge.js
```

The bridge reads Claude Code status-line JSON from stdin and writes only the five-hour/weekly usage percentage and reset timestamp to the app support folder. If you already use a status-line command, call the bridge with `--forward "<existing command>"` so the existing status line still renders.

## GW inspection

Read-only login-page inspection uses Playwright, matching the workspace rule for browser debugging:

```bash
cd mac-work-timer
npm exec --yes --package=playwright -- playwright install chromium
npm exec --yes --package=playwright -- node scripts/inspect_gw_login.mjs https://gw.example.com/gw/bizbox.do
```

Use this only to inspect forms, navigation, and read-only attendance pages. Do not call attendance write endpoints from this app.

The weekly balance follows the same rule: the WebKit probe only navigates through visible GW menus and reads table text. If 2FA prevents access, the daily timer continues and any previously confirmed weekly cache remains unchanged.
