# ClawWatch

A native macOS menubar app (SwiftUI) that monitors your [OpenClaw](https://openclaw.ai) gateway status.

## Features

- **Menubar icon** that changes color based on gateway health:
  - 🟢 Green — gateway running, no issues
  - 🟡 Yellow — gateway running but degraded (stale logs or recent errors)
  - 🔴 Red — gateway process not running or unresponsive
- **Polls every 15 seconds** (process check + WebSocket probe + log freshness)
- **Agent list** — shows agents discovered from `~/.openclaw/agents/`
- **Log access** — copy recent logs, error logs, or error context to clipboard
- **Gateway control** — restart gateway with confirmation dialog
- **Open Dashboard** — opens `http://127.0.0.1:18790/` in your browser

## Build

### Requirements
- macOS 14+ (Sonoma)
- Swift 5.9+ (comes with Xcode or via swift.org)

### Debug build
```bash
swift build
```

### Release build
```bash
swift build -c release
```

Binary will be at `.build/release/ClawWatch`.

## Installation

### Option 1: Copy to /usr/local/bin (CLI-style)
```bash
swift build -c release
cp .build/release/ClawWatch /usr/local/bin/ClawWatch
```
Then launch it from Terminal:
```bash
ClawWatch &
```

### Option 2: Create a .app bundle (recommended for menubar)
```bash
swift build -c release

APP_DIR="$HOME/Applications/ClawWatch.app/Contents/MacOS"
mkdir -p "$APP_DIR"
cp .build/release/ClawWatch "$APP_DIR/"

# Create Info.plist (sets LSUIElement for dock hiding)
cat > "$HOME/Applications/ClawWatch.app/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>ai.openclaw.clawwatch</string>
    <key>CFBundleName</key>
    <string>ClawWatch</string>
    <key>CFBundleExecutable</key>
    <string>ClawWatch</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
EOF

open "$HOME/Applications/ClawWatch.app"
```

## Launch at Login (LaunchAgent)

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
        <!-- Use the .app bundle path if you created one -->
        <string>/Users/YOUR_USERNAME/Applications/ClawWatch.app/Contents/MacOS/ClawWatch</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>StandardOutPath</key>
    <string>/tmp/clawwatch.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/clawwatch.err.log</string>
</dict>
</plist>
```

Load it:
```bash
launchctl load ~/Library/LaunchAgents/ai.openclaw.clawwatch.plist
```

Or add `ClawWatch.app` to **System Settings → General → Login Items**.

## Status Detection Logic

1. **Process check** — `pgrep -f "openclaw.*gateway"` 
2. **WebSocket probe** — connects to `ws://127.0.0.1:18790` (falls back to HTTP HEAD)
3. **Log freshness** — checks `~/.openclaw/logs/gateway.log` mtime; yellow if >5 min stale
4. **Error scan** — scans last 100 lines of `~/.openclaw/logs/gateway.err.log` for error patterns

### Error patterns detected
`ECONNREFUSED`, `ECONNRESET`, `ETIMEDOUT`, `SIGTERM`, `SIGKILL`, `SIGSEGV`,
`out of memory`, `OOM`, `heap out of memory`, `rate limit`, `429`, `quota`,
`unhandled rejection`, `uncaught exception`, `getUpdates conflict`,
`FATAL`, `PANIC`, `Error:`, stack trace lines (`    at ...`)

## File Structure

```
ClawWatch/
├── Package.swift
├── Sources/
│   └── ClawWatch/
│       ├── ClawWatchApp.swift      # App entry, menubar setup, NSMenu building
│       ├── StatusMonitor.swift      # Polling logic, process/WS/log checks
│       ├── LogParser.swift          # Error pattern matching, log reading
│       ├── AgentStatus.swift        # Agent discovery from ~/.openclaw/agents/
│       └── ClipboardHelper.swift    # Copy-to-clipboard functions
└── README.md
```

## Notes

- No code signing required for local use
- `LSUIElement` is set via `NSApp.setActivationPolicy(.accessory)` at runtime (no dock icon)
- When built as a `.app` bundle, the `Info.plist` in the bundle also sets `LSUIElement = true`
