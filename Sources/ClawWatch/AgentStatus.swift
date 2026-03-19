import Foundation

struct AgentInfo {
    let name: String
    var indicator: String

    init(name: String) {
        self.name = name
        self.indicator = "●"
    }
}

struct AgentStatus {
    static let defaultAgents = ["main", "alfred", "dewey", "rusk", "ghost", "spooner", "carver"]

    /// Discover agents from ~/.openclaw/agents/ directory.
    /// Falls back to the default list if the directory doesn't exist or is empty.
    static func discoverAgents() -> [AgentInfo] {
        let agentsPath = NSString("~/.openclaw/agents").expandingTildeInPath
        let fm = FileManager.default

        var agentNames: [String] = []

        if let contents = try? fm.contentsOfDirectory(atPath: agentsPath) {
            var isDir: ObjCBool = false
            for item in contents.sorted() {
                let fullPath = (agentsPath as NSString).appendingPathComponent(item)
                if fm.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
                    agentNames.append(item)
                }
            }
        }

        if agentNames.isEmpty {
            agentNames = defaultAgents
        }

        return agentNames.map { name in
            var info = AgentInfo(name: name)
            info.indicator = agentIndicator(for: name, agentsPath: agentsPath)
            return info
        }
    }

    /// Returns a status indicator for an agent.
    /// Currently just checks if the agent directory exists; future: check session socket/pid.
    private static func agentIndicator(for name: String, agentsPath: String) -> String {
        let agentPath = (agentsPath as NSString).appendingPathComponent(name)
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: agentPath, isDirectory: &isDir)

        if exists && isDir.boolValue {
            // Check for a recent activity file (e.g., pid or session file)
            let sessionFiles = ["session.json", "pid", ".pid", "agent.pid"]
            for sf in sessionFiles {
                let sfPath = (agentPath as NSString).appendingPathComponent(sf)
                if FileManager.default.fileExists(atPath: sfPath) {
                    // Has a session file — likely active
                    return "🟢"
                }
            }
            // Directory exists but no session file
            return "⚫"
        }

        return "⚫"
    }
}
