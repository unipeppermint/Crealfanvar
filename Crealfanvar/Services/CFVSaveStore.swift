import Foundation

nonisolated struct CFVSession: Codable, Equatable {
    var schemaVersion = 1
    var contentVersion = 1
    var rulesVersion = 1
    let levelID: String
    var state: CFVState
    var history = [CFVState]()
    var actions = [CFVAction]()
    var completionID: String? = nil
    var rewardPresented = false

    init(level: CFVLevel) {
        levelID = level.levelID
        state = level.initialState
    }

    mutating func commit(_ turn: CFVTurn, action: CFVAction) {
        history.append(state)
        actions.append(action)
        state = turn.state
        if state.outcome == .won { completionID = UUID().uuidString }
    }

    mutating func undo() {
        guard state.outcome != .won, let previous = history.popLast() else { return }
        let revision = state.revision + 1
        state = previous
        state.revision = revision
        actions.removeLast()
    }
}

nonisolated struct CFVProgress: Codable {
    var schemaVersion = 1
    var contentVersion = 1
    var rulesVersion = 1
    var completed = Set<String>()
    var bestMoves = [String: Int]()
    var completionIDs = Set<String>()
    var seenTutorials = Set<String>()
}

nonisolated enum CFVSaveError: Error { case invalid, incompatible }

nonisolated final class CFVSaveStore {
    let directory: URL
    var notices = [String]()
    var injectWriteFailure = false
    private let repository: CFVRepository

    init(directory: URL, repository: CFVRepository) throws {
        self.directory = directory
        self.repository = repository
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func write<T: Codable>(_ value: T, name: String, validate: (T) throws -> Void) throws {
        if injectWriteFailure { throw CocoaError(.fileWriteOutOfSpace) }
        try validate(value)
        let data = try JSONEncoder().encode(value)
        _ = try JSONDecoder().decode(T.self, from: data)
        let url = directory.appendingPathComponent(name + ".json")
        if let old = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode(T.self, from: old), (try? validate(decoded)) != nil {
            try old.write(to: directory.appendingPathComponent(name + ".backup.json"), options: .atomic)
        }
        try data.write(to: url, options: .atomic)
    }

    private func read<T: Codable>(_ type: T.Type, name: String, validate: (T) throws -> Void) -> T? {
        for suffix in [".json", ".backup.json"] {
            let url = directory.appendingPathComponent(name + suffix)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            do {
                let value = try JSONDecoder().decode(type, from: Data(contentsOf: url))
                try validate(value)
                if suffix.contains("backup") { notices.append(name + ":backup") }
                return value
            } catch {
                notices.append(name + ":damaged")
                // Preserve evidence; never replace a damaged file with empty progress.
                let copy = directory.appendingPathComponent(name + "-fault-" + UUID().uuidString + ".json")
                try? FileManager.default.copyItem(at: url, to: copy)
            }
        }
        return nil
    }

    private func validateProgress(_ progress: CFVProgress) throws {
        guard progress.schemaVersion == 1, progress.contentVersion == 1, progress.rulesVersion == 1,
              progress.completed.isSubset(of: Set(repository.catalog.levelIDs)),
              progress.bestMoves.keys.allSatisfy({ progress.completed.contains($0) }),
              progress.bestMoves.values.allSatisfy({ $0 > 0 && $0 <= 12 }) else { throw CFVSaveError.incompatible }
    }

    private func validateSession(_ session: CFVSession) throws {
        guard session.schemaVersion == 1, session.contentVersion == 1, session.rulesVersion == 1,
              let level = repository.levels.first(where: { $0.levelID == session.levelID }),
              session.history.count == session.actions.count, session.actions.count <= level.moveLimit else { throw CFVSaveError.incompatible }
        var replay = level.initialState
        for index in session.actions.indices {
            let snapshot = session.history[index]
            guard snapshot.tiles == replay.tiles, snapshot.remainingMoves == replay.remainingMoves,
                  snapshot.outcome == replay.outcome,
                  let turn = CFVEngine.apply(level, replay, session.actions[index]) else { throw CFVSaveError.invalid }
            replay = turn.state
        }
        guard replay.tiles == session.state.tiles, replay.remainingMoves == session.state.remainingMoves,
              replay.outcome == session.state.outcome,
              (session.state.outcome == .won) == (session.completionID != nil) else { throw CFVSaveError.invalid }
    }

    func loadProgress() -> CFVProgress {
        read(CFVProgress.self, name: "progress", validate: validateProgress) ?? CFVProgress()
    }

    func loadSession() -> CFVSession? {
        if let saved = read(CFVSession.self, name: "session", validate: validateSession) { return saved }
        // An incompatible or damaged board may still identify its level. Restart only that level.
        let url = directory.appendingPathComponent("session.json")
        if let data = try? Data(contentsOf: url),
           let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let id = raw["levelID"] as? String,
           let level = repository.levels.first(where: { $0.levelID == id }) {
            notices.append("session:restarted")
            return CFVSession(level: level)
        }
        return nil
    }

    func saveSession(_ session: CFVSession) throws {
        try write(session, name: "session", validate: validateSession)
    }

    func saveProgress(_ progress: CFVProgress) throws {
        try write(progress, name: "progress", validate: validateProgress)
    }

    func reconcile(_ session: CFVSession, progress: CFVProgress) throws -> CFVProgress {
        guard session.state.outcome == .won, let id = session.completionID else { return progress }
        var next = progress
        next.completed.insert(session.levelID)
        next.completionIDs.insert(id)
        next.bestMoves[session.levelID] = min(next.bestMoves[session.levelID] ?? Int.max, session.actions.count)
        try saveProgress(next)
        return next
    }
}
