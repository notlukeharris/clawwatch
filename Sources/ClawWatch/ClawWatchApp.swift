import SwiftUI
import AppKit

@main
struct ClawWatchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No windows — menubar only
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var statusMonitor: StatusMonitor?
    var menu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusMonitor = StatusMonitor()
        statusMonitor?.delegate = self

        if let button = statusItem?.button {
            button.image = statusImage(for: .unknown)
            button.action = #selector(statusItemClicked)
            button.target = self
        }

        statusMonitor?.startPolling()
    }

    @objc func statusItemClicked() {
        rebuildMenu()
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    func rebuildMenu() {
        guard let monitor = statusMonitor else { return }
        let m = NSMenu()

        // 1. Status header
        let state = monitor.currentState
        let headerItem = NSMenuItem(title: statusTitle(for: state), action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        m.addItem(headerItem)

        m.addItem(.separator())

        // 3. Agent list
        let agentHeaderItem = NSMenuItem(title: "Agents:", action: nil, keyEquivalent: "")
        agentHeaderItem.isEnabled = false
        m.addItem(agentHeaderItem)

        let agents = AgentStatus.discoverAgents()
        if agents.isEmpty {
            let emptyItem = NSMenuItem(title: "  (no agents found)", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            m.addItem(emptyItem)
        } else {
            for agent in agents {
                let item = NSMenuItem(title: "  \(agent.indicator) \(agent.name)", action: nil, keyEquivalent: "")
                item.isEnabled = false
                m.addItem(item)
            }
        }

        m.addItem(.separator())

        // 5. Last error
        let lastError = LogParser.lastError()
        let errorTitle = lastError.map { truncate($0, to: 60) } ?? "No recent errors ✓"
        let errorItem = NSMenuItem(title: "⚠️ \(errorTitle)", action: nil, keyEquivalent: "")
        errorItem.isEnabled = false
        m.addItem(errorItem)

        // 6. Copy recent logs
        let copyLogsItem = NSMenuItem(title: "Copy Recent Logs", action: #selector(copyRecentLogs), keyEquivalent: "")
        copyLogsItem.target = self
        m.addItem(copyLogsItem)

        // 7. Copy error logs
        let copyErrItem = NSMenuItem(title: "Copy Error Logs", action: #selector(copyErrorLogs), keyEquivalent: "")
        copyErrItem.target = self
        m.addItem(copyErrItem)

        // 8. Copy error context
        let copyCtxItem = NSMenuItem(title: "Copy Error Context", action: #selector(copyErrorContext), keyEquivalent: "")
        copyCtxItem.target = self
        m.addItem(copyCtxItem)

        m.addItem(.separator())

        // 10. Restart Gateway
        let restartItem = NSMenuItem(title: "Restart Gateway", action: #selector(restartGateway), keyEquivalent: "")
        restartItem.target = self
        m.addItem(restartItem)

        // 11. Open Dashboard
        let dashItem = NSMenuItem(title: "Open Dashboard", action: #selector(openDashboard), keyEquivalent: "")
        dashItem.target = self
        m.addItem(dashItem)

        m.addItem(.separator())

        // 13. Quit
        let quitItem = NSMenuItem(title: "Quit ClawWatch", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        m.addItem(quitItem)

        self.menu = m
    }

    // MARK: - Actions

    @objc func copyRecentLogs() {
        ClipboardHelper.copyRecentLogs()
    }

    @objc func copyErrorLogs() {
        ClipboardHelper.copyErrorLogs()
    }

    @objc func copyErrorContext() {
        ClipboardHelper.copyErrorContext()
    }

    @objc func restartGateway() {
        let alert = NSAlert()
        alert.messageText = "Restart Gateway?"
        alert.informativeText = "This will run 'openclaw gateway restart'."
        alert.addButton(withTitle: "Restart")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            runShell("openclaw gateway restart")
        }
    }

    @objc func openDashboard() {
        if let url = URL(string: "http://127.0.0.1:18790/") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Helpers

    func statusTitle(for state: GatewayState) -> String {
        switch state {
        case .running:  return "🟢 OpenClaw: Running"
        case .degraded: return "🟡 OpenClaw: Degraded"
        case .down:     return "🔴 OpenClaw: Down"
        case .unknown:  return "⚪ OpenClaw: Checking…"
        }
    }

    func statusImage(for state: GatewayState) -> NSImage? {
        let symbolName = "circle.fill"
        let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        let config: NSImage.SymbolConfiguration
        switch state {
        case .running:
            config = NSImage.SymbolConfiguration(paletteColors: [.systemGreen])
        case .degraded:
            config = NSImage.SymbolConfiguration(paletteColors: [.systemYellow])
        case .down:
            config = NSImage.SymbolConfiguration(paletteColors: [.systemRed])
        case .unknown:
            config = NSImage.SymbolConfiguration(paletteColors: [.systemGray])
        }
        return img?.withSymbolConfiguration(config)
    }

    func truncate(_ s: String, to length: Int) -> String {
        if s.count <= length { return s }
        return String(s.prefix(length)) + "…"
    }

    func runShell(_ command: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", command]
        try? task.run()
    }
}

extension AppDelegate: StatusMonitorDelegate {
    func statusDidUpdate(_ state: GatewayState) {
        DispatchQueue.main.async {
            self.statusItem?.button?.image = self.statusImage(for: state)
        }
    }
}
