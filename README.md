# ClawWatch

A native macOS menubar app that monitors your [OpenClaw](https://github.com/openclaw/openclaw) gateway at a glance.

No browser tabs. No terminal windows. Just a colored dot in your menubar that tells you if your agents are running.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## What It Does

**Menubar indicator:**
- 🟢 **Green** — Gateway running, no issues
- 🟡 **Yellow** — Gateway running but errors detected
- 🔴 **Red** — Gateway is down or unresponsive

**Agent roster** — shows every agent in your `~/.openclaw/agents/` directory with live status:
- 🔵 **Working** — actively processing (< 2 min ago)
- 🟢 **Ready** — healthy, recently active (< 30 min)
- ⚪ **Idle** — not currently in use, with time since last activity

**Diagnostics (one click):**
- **Copy Recent Logs** — last 200 lines of `gateway.log` → clipboard
- **Copy Error Logs** — last 100 lines of `gateway.err.log` → clipboard
- **Copy Error Context** — finds the last crash/error, grabs ±20 lines of surrounding context → clipboard (ready to paste into any LLM for diagnosis)

**Actions:**
- **Restart Gateway** — one click (with confirmation)
- **Open Dashboard** — opens the gateway web UI

## Install

### Build from source

```bash
git clone https://github.com/openclaw/clawwatch.git
cd clawwatch
swift build -c release
```

### Run

```bash
.build/release/ClawWatch &
```

### Launch at login (optional)

Create `~/Library/LaunchAgents/ai.openclaw.clawwatch.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>ai.openclaw.clawwatch</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/ClawWatch</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
```

Then:
```bash
cp .build/release/ClawWatch /usr/local/bin/
launchctl load ~/Library/LaunchAgents/ai.openclaw.clawwatch.plist
```

## How It Works

ClawWatch polls every 15 seconds:

1. **Process check** — verifies the gateway process is alive via `pgrep`
2. **Network probe** — connects to `ws://127.0.0.1:18790` to confirm the gateway is responsive
3. **Log freshness** — checks `~/.openclaw/logs/gateway.log` modification time
4. **Error scan** — parses recent `gateway.err.log` entries for crash patterns, connection failures, rate limits, and OOM errors

Agent status is determined by reading `sessions.json` timestamps — no API calls, no LLM inference, just filesystem reads.

### Error Detection

ClawWatch flags real problems and ignores normal operational noise:

**Triggers yellow:**
`ECONNREFUSED` · `ETIMEDOUT` · `SIGKILL` · `out of memory` · `rate limit` · `429` · `unhandled rejection` · `uncaught exception` · `FATAL` · stack traces

**Ignored (benign):**
`getUpdates conflict` (normal Telegram reconnection) · `Skipping skill path` (config warning)

## Requirements

- macOS 14 (Sonoma) or later
- [OpenClaw](https://github.com/openclaw/openclaw) installed and configured
- Swift 5.9+ toolchain (for building from source)

## Configuration

Currently reads from default OpenClaw paths:
- Gateway: `ws://127.0.0.1:18790`
- Logs: `~/.openclaw/logs/`
- Agents: `~/.openclaw/agents/`

Custom port/path configuration coming in a future release.

## License

MIT
