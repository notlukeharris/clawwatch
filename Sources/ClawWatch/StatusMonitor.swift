import Foundation
import Network

enum GatewayState {
    case running
    case degraded
    case down
    case unknown
}

protocol StatusMonitorDelegate: AnyObject {
    func statusDidUpdate(_ state: GatewayState)
}

class StatusMonitor {
    weak var delegate: StatusMonitorDelegate?
    private(set) var currentState: GatewayState = .unknown
    private var timer: Timer?
    private let pollInterval: TimeInterval = 15.0

    func startPolling() {
        checkStatus()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.checkStatus()
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func checkStatus() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            let newState = self.determineState()
            DispatchQueue.main.async {
                self.currentState = newState
                self.delegate?.statusDidUpdate(newState)
            }
        }
    }

    private func determineState() -> GatewayState {
        let processRunning = checkProcess()
        let httpAlive = checkHTTP()

        // If neither process nor HTTP is alive, it's down
        if !processRunning && !httpAlive {
            return .down
        }

        // Check for degraded conditions
        let logStale = checkLogFreshness()
        let hasRecentErrors = checkRecentErrors()

        if logStale || hasRecentErrors {
            return .degraded
        }

        return .running
    }

    // MARK: - Process Check
    private func checkProcess() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-f", "openclaw.*gateway"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    // MARK: - HTTP Health Check
    private func checkHTTP() -> Bool {
        guard let url = URL(string: "http://127.0.0.1:18790/") else { return false }
        var request = URLRequest(url: url, timeoutInterval: 3.0)
        request.httpMethod = "HEAD"
        var alive = false
        let semaphore = DispatchSemaphore(value: 0)
        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            if let httpResp = response as? HTTPURLResponse {
                alive = httpResp.statusCode < 600
            } else if error == nil {
                alive = true
            }
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 4.0)
        return alive
    }

    // MARK: - Log Freshness
    private func checkLogFreshness() -> Bool {
        let logPath = NSString("~/.openclaw/logs/gateway.log").expandingTildeInPath
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: logPath),
              let modified = attrs[.modificationDate] as? Date else {
            return false // Can't check → don't flag yellow
        }
        let age = Date().timeIntervalSince(modified)
        return age > 5 * 60 // Stale if >5 minutes
    }

    // MARK: - Recent Errors
    private func checkRecentErrors() -> Bool {
        let errLogPath = NSString("~/.openclaw/logs/gateway.err.log").expandingTildeInPath
        guard let lines = LogParser.tailLines(from: errLogPath, count: 100) else {
            return false
        }
        let fiveMinAgo = Date().addingTimeInterval(-5 * 60)
        for line in lines {
            if LogParser.isErrorLine(line) {
                // If we can't determine timestamp, treat any recent error as worth flagging
                return true
            }
        }
        _ = fiveMinAgo // suppress unused warning
        return false
    }
}
