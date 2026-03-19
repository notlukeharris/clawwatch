import Foundation

struct LogParser {

    // MARK: - Error Patterns
    static let errorPatterns: [String] = [
        "ECONNREFUSED",
        "ECONNRESET",
        "ETIMEDOUT",
        "SIGTERM",
        "SIGKILL",
        "SIGSEGV",
        "out of memory",
        "OOM",
        "heap out of memory",
        "rate limit",
        "429",
        "quota",
        "unhandled rejection",
        "uncaught exception",
        "FATAL",
        "PANIC",
        "Error:",
    ]

    /// Known-benign patterns that match errorPatterns but aren't real problems
    static let ignoredPatterns: [String] = [
        "getUpdates conflict",           // Normal Telegram long-poll reconnection
        "Skipping skill path",           // Config warning, not an error
    ]

    static func isErrorLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return false }

        // Stack trace lines
        if trimmed.hasPrefix("at ") {
            return true
        }

        let lower = line.lowercased()

        // Check if it matches an ignored pattern first
        for ignored in ignoredPatterns {
            if lower.contains(ignored.lowercased()) {
                return false
            }
        }

        for pattern in errorPatterns {
            if lower.contains(pattern.lowercased()) {
                return true
            }
        }
        return false
    }

    // MARK: - Last Error
    static func lastError() -> String? {
        let errLogPath = NSString("~/.openclaw/logs/gateway.err.log").expandingTildeInPath
        guard let lines = tailLines(from: errLogPath, count: 100) else { return nil }
        for line in lines.reversed() {
            if isErrorLine(line) && !line.trimmingCharacters(in: .whitespaces).isEmpty {
                return line.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    // MARK: - Tail Lines
    static func tailLines(from path: String, count: Int) -> [String]? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }
        let lines = content.components(separatedBy: "\n")
        let tail = lines.suffix(count)
        return Array(tail)
    }

    // MARK: - Error Context
    /// Finds the last error line, returns 20 lines before and 20 after with a header.
    static func errorContext() -> String? {
        let errLogPath = NSString("~/.openclaw/logs/gateway.err.log").expandingTildeInPath
        guard let content = try? String(contentsOfFile: errLogPath, encoding: .utf8) else {
            return nil
        }
        let lines = content.components(separatedBy: "\n")

        // Find last error line index
        var lastErrorIdx: Int? = nil
        for (i, line) in lines.enumerated() {
            if isErrorLine(line) && !line.trimmingCharacters(in: .whitespaces).isEmpty {
                lastErrorIdx = i
            }
        }

        guard let errIdx = lastErrorIdx else { return nil }

        let startIdx = max(0, errIdx - 20)
        let endIdx = min(lines.count - 1, errIdx + 20)
        let contextLines = lines[startIdx...endIdx]

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = formatter.string(from: Date())

        var result = "=== ClawWatch Error Context ===\n"
        result += "Captured: \(timestamp)\n"
        result += "Lines \(startIdx + 1)–\(endIdx + 1) of \(lines.count)\n"
        result += "---\n"
        result += contextLines.joined(separator: "\n")
        return result
    }

    // MARK: - Recent Logs (last N lines of gateway.log)
    static func recentLogs(count: Int = 200) -> String? {
        let logPath = NSString("~/.openclaw/logs/gateway.log").expandingTildeInPath
        guard let lines = tailLines(from: logPath, count: count) else { return nil }
        return lines.joined(separator: "\n")
    }

    // MARK: - Error Logs (last N lines of gateway.err.log)
    static func errorLogs(count: Int = 100) -> String? {
        let errLogPath = NSString("~/.openclaw/logs/gateway.err.log").expandingTildeInPath
        guard let lines = tailLines(from: errLogPath, count: count) else { return nil }
        return lines.joined(separator: "\n")
    }
}
