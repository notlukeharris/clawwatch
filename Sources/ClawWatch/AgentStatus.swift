import Foundation

struct AgentInfo {
    let name: String
    var indicator: String
    var detail: String

    init(name: String) {
        self.name = name
        self.indicator = "⚫"
        self.detail = ""
    }
}

struct AgentStatus {
    static let defaultAgents = ["main", "alfred", "dewey", "rusk", "ghost", "spooner", "carver"]

    /// Discover agents from ~/.openclaw/agents/ directory.
    /// Filters out dotfiles/dotfolders (e.g. .stfolder from Syncthing).
    /// Falls back to the default list if the directory doesn't exist or is empty.
    static func discoverAgents() -> [AgentInfo] {
        let agentsPath = NSString("~/.openclaw/agents").expandingTildeInPath
        let fm = FileManager.default

        var agentNames: [String] = []

        if let contents = try? fm.contentsOfDirectory(atPath: agentsPath) {
            var isDir: ObjCBool = false
            for item in contents.sorted() {
                // Skip dotfiles/dotfolders
                if item.hasPrefix(".") { continue }
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
            let (indicator, detail) = agentIndicator(for: name, agentsPath: agentsPath)
            info.indicator = indicator
            info.detail = detail
            return info
        }
    }

    /// Returns a status indicator for an agent by checking sessions/sessions.json.
    /// 🔵 = actively working right now (updated within last 2 minutes)
    /// 🟢 = healthy/ready (updated within last 30 minutes)
    /// ⚪ = idle (no recent activity)
    private static func agentIndicator(for name: String, agentsPath: String) -> (String, String) {
        let agentPath = (agentsPath as NSString).appendingPathComponent(name)
        let sessionsFile = (agentPath as NSString)
            .appendingPathComponent("sessions")
            .appending("/sessions.json")

        guard FileManager.default.fileExists(atPath: sessionsFile),
              let data = try? Data(contentsOf: URL(fileURLWithPath: sessionsFile)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ("⚪", "no sessions")
        }

        // Find the most recent updatedAt across all session entries
        var latestUpdate: Double = 0
        for (_, value) in json {
            if let session = value as? [String: Any],
               let updatedAt = session["updatedAt"] as? Double {
                latestUpdate = max(latestUpdate, updatedAt)
            }
        }

        if latestUpdate == 0 {
            return ("⚪", "no activity")
        }

        let lastUpdateDate = Date(timeIntervalSince1970: latestUpdate / 1000.0)
        let minutesAgo = -lastUpdateDate.timeIntervalSinceNow / 60.0

        if minutesAgo < 2 {
            return ("🔵", "working")
        } else if minutesAgo < 30 {
            let ago = "\(Int(minutesAgo))m ago"
            return ("🟢", ago)
        } else if minutesAgo < 60 {
            return ("⚪", "\(Int(minutesAgo))m ago")
        } else if minutesAgo < 1440 {
            let hoursAgo = Int(minutesAgo / 60)
            return ("⚪", "\(hoursAgo)h ago")
        } else {
            let daysAgo = Int(minutesAgo / 1440)
            return ("⚪", "\(daysAgo)d ago")
        }
    }
}
