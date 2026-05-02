import Foundation

enum SessionStore {
    private static let writeQueue = DispatchQueue(label: "com.veira.sessionstore.write", qos: .utility)
    private static let genLock = NSLock()
    private static var writeGeneration: Int = 0

    private static func nextGeneration() -> Int {
        genLock.lock(); defer { genLock.unlock() }
        writeGeneration += 1
        return writeGeneration
    }

    private static func currentGeneration() -> Int {
        genLock.lock(); defer { genLock.unlock() }
        return writeGeneration
    }

    private static var fileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let veiraDir = support.appendingPathComponent("Veira", isDirectory: true)
        let veiraFile = veiraDir.appendingPathComponent("workdays.json")

        // One-time migration: copy data from the legacy ProjectPulse directory if
        // the Veira file doesn't exist yet. The original file is left in place.
        if !FileManager.default.fileExists(atPath: veiraFile.path) {
            let legacyFile = support
                .appendingPathComponent("ProjectPulse", isDirectory: true)
                .appendingPathComponent("workdays.json")
            if FileManager.default.fileExists(atPath: legacyFile.path) {
                try? FileManager.default.createDirectory(at: veiraDir, withIntermediateDirectories: true)
                try? FileManager.default.copyItem(at: legacyFile, to: veiraFile)
            }
        }

        try? FileManager.default.createDirectory(at: veiraDir, withIntermediateDirectories: true)
        return veiraFile
    }

    static func load() -> [WorkDayRecord] {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        guard let data = try? Data(contentsOf: url) else { return [] }

        do {
            return try JSONDecoder().decode([WorkDayRecord].self, from: data).map { record in
                var r = record
                r.sessions = deduplicated(record.sessions)
                return r
            }
        } catch {
            print("[SessionStore] Failed to decode workdays.json: \(error)")
            // Preserve the unreadable file before returning an empty list.
            // A subsequent save() will write to the original path without overwriting this backup.
            let backupURL = url.deletingLastPathComponent().appendingPathComponent("workdays.json.corrupt")
            try? FileManager.default.removeItem(at: backupURL)
            try? FileManager.default.copyItem(at: url, to: backupURL)
            return []
        }
    }

    static func save(_ workDays: [WorkDayRecord]) {
        guard let data = try? JSONEncoder().encode(workDays) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func saveAsync(_ workDays: [WorkDayRecord]) {
        let url = fileURL
        let gen = nextGeneration()
        writeQueue.async {
            guard currentGeneration() == gen else { return }
            guard let data = try? JSONEncoder().encode(workDays) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    private static func deduplicated(_ sessions: [TrackedSession]) -> [TrackedSession] {
        var best: [UUID: TrackedSession] = [:]
        for session in sessions {
            if let existing = best[session.id] {
                if session.endedAt > existing.endedAt ||
                   (session.endedAt == existing.endedAt && session.segmentDuration > existing.segmentDuration) {
                    best[session.id] = session
                }
            } else {
                best[session.id] = session
            }
        }
        var seen = Set<UUID>()
        return sessions.compactMap { s in
            seen.insert(s.id).inserted ? best[s.id] : nil
        }
    }
}
