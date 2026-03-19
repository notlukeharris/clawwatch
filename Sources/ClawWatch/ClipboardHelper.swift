import AppKit

struct ClipboardHelper {

    static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Copies the last 200 lines of gateway.log to clipboard.
    static func copyRecentLogs() {
        if let logs = LogParser.recentLogs(count: 200) {
            copy(logs)
            notify("Copied last 200 lines of gateway.log")
        } else {
            notify("Could not read gateway.log")
        }
    }

    /// Copies the last 100 lines of gateway.err.log to clipboard.
    static func copyErrorLogs() {
        if let logs = LogParser.errorLogs(count: 100) {
            copy(logs)
            notify("Copied last 100 lines of gateway.err.log")
        } else {
            notify("Could not read gateway.err.log")
        }
    }

    /// Finds the last error pattern, grabs ±20 lines, copies to clipboard.
    static func copyErrorContext() {
        if let ctx = LogParser.errorContext() {
            copy(ctx)
            notify("Copied error context to clipboard")
        } else {
            notify("No error context found")
        }
    }

    // MARK: - Notification
    private static func notify(_ message: String) {
        // Brief user notification via NSUserNotification (deprecated) or just
        // a beep/no-op. On macOS 14+ we'd use UserNotifications framework,
        // but that requires entitlements. Instead, show a brief alert-free
        // confirmation by posting to the status bar or just log.
        //
        // For simplicity: use NSAlert in background thread — but that's bad UX.
        // Best approach: update the menu item temporarily. For now, just print.
        print("[ClawWatch] \(message)")
    }
}
