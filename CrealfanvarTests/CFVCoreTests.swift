import Foundation

@main
struct CFVCoreTests {
    static var checks = 0
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        if !condition() { fatalError("FAIL: " + message) }
    }

    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let repo = try CFVRepository(directory: root.appendingPathComponent("Crealfanvar/Resources"))
        check(repo.levels.count == 24 && repo.catalog.learningStages.count == 6, "24 levels across six chapters")
        for level in repo.levels {
            var session = CFVSession(level: level)
            check(CFVEngine.matches(session.state).isEmpty, "initial match")
            for action in level.referenceSolution {
                let before = session
                let turn = CFVEngine.apply(level, session.state, action)!
                if action.type == "fold" {
                    let fold = level.folds.first { $0.creaseID == action.creaseID }!
                    check(CFVEngine.matches(session.state, projection: CFVEngine.projection(fold)) == turn.removedIDs, "preview == commit")
                }
                session.commit(turn, action: action)
                if session.state.outcome != .won {
                    var undone = session
                    undone.undo()
                    check(undone.state.tiles == before.state.tiles && undone.state.remainingMoves == before.state.remainingMoves && undone.actions == before.actions, "undo restores")
                }
            }
            check(session.state.outcome == .won && session.state.remainingMoves == 0, "last step win")
            check(CFVEngine.apply(level, session.state, level.referenceSolution[0]) == nil, "duplicate win blocked")
            if case .foundPath(let path) = CFVHintSolver.solve(level: level, state: level.initialState) {
                check(path == level.referenceSolution, "reference hint")
            } else { fatalError("missing hint") }
            print("PASS \(level.levelID): \(session.actions.count) moves, \(level.targetCells.count) targets")
        }
        // All four fold directions and all supported widths map onto stationary paper.
        for (axis, sides) in [("vertical", ["left", "right"]), ("horizontal", ["top", "bottom"])] {
            for side in sides {
                for width in 1...3 {
                    let k = ["left", "top"].contains(side) ? width : 6 - width
                    let fold = CFVFold(creaseID: "test", axis: axis, boundary: k, movingSide: side)
                    check(fold.isValid, "valid geometry")
                    let projection = CFVEngine.projection(fold)
                    check(projection.stacks.flatMap { $0 }.sorted() == Array(0..<36), "paper exactly once")
                    for cell in 0..<36 where fold.isMoving(cell) {
                        check(projection.topCells[fold.destination(cell)] == cell, "moving paper on top")
                    }
                }
            }
        }
        let right = CFVFold(creaseID: "right-two", axis: "vertical", boundary: 4, movingSide: "right")
        let sample = CFVLevel(levelID: "sample", contentVersion: 1, rulesVersion: 1, learningStage: "test", titleZH: "", titleEN: "", purposeZH: "", purposeEN: "", initialRows: ["LTCLCT", "CLTCLC", "LLCTLL", "LTCLTC", "CLTCLT", "TCLTCL"], targetCells: [12,17], moveLimit: 1, folds: [right], referenceSolution: [.fold("right-two")], tutorialCells: [], tutorialCrease: nil)
        let turn = CFVEngine.apply(sample, sample.initialState, .fold("right-two"))!
        check(turn.removedIDs == Set([12,13,16,17]) && turn.targetDelta == 2 && turn.state.outcome == .won, "baseline sample")
        check(turn.state.tiles[14] != nil && turn.state.tiles[15] != nil, "hidden survives")
        var blank = sample.initialState
        blank.tiles[16] = nil
        check(CFVEngine.projection(right).topCells[15] == 16, "blank remains paper")
        check(CFVEngine.matches(blank, projection: CFVEngine.projection(right)) == Set([12,13,17]), "blank stops run and does not expose lower tile")
        var cross = CFVState(tiles: Array(repeating: nil, count: 36), remainingMoves: 1)
        for i in [8,13,14,15,20] { cross.tiles[i] = CFVTile(id: i, kind: .leaf, isTarget: true) }
        check(CFVEngine.matches(cross).count == 5, "cross dedup")
        let level = repo.levels[3]
        var session = CFVSession(level: level)
        let initial = session
        check(CFVEngine.apply(level, session.state, .swap(0,35)) == nil && session == initial, "invalid unchanged")
        let dir = root.appendingPathComponent("artifacts/validation/save-fixtures-" + UUID().uuidString)
        let store = try CFVSaveStore(directory: dir, repository: repo)
        try store.saveSession(session)
        session.commit(CFVEngine.apply(level, session.state, level.referenceSolution[0])!, action: level.referenceSolution[0])
        try store.saveSession(session)
        check(store.loadSession() == session, "roundtrip")
        try Data("broken".utf8).write(to: dir.appendingPathComponent("session.json"))
        check(store.loadSession() == initial, "backup restore")
        store.injectWriteFailure = true
        do { try store.saveSession(session); fatalError("write should fail") } catch { checks += 1 }
        store.injectWriteFailure = false
        try store.saveSession(session)
        session.commit(CFVEngine.apply(level, session.state, level.referenceSolution[1])!, action: level.referenceSolution[1])
        try store.saveSession(session)
        var progress = try store.reconcile(session, progress: CFVProgress())
        progress = try store.reconcile(session, progress: progress)
        check(progress.completed.count == 1 && progress.completionIDs.count == 1, "idempotent reward")
        check(repo.catalog.stage(repo.catalog.creatures[1], completed: progress.completed) == 1, "missing prior no unlock")
        for count in 0...repo.levels.count {
            let completed = Set(repo.catalog.levelIDs.prefix(count))
            let stages = repo.catalog.creatures.map { repo.catalog.stage($0, completed: completed) }
            check(stages.filter { $0 == 2 }.count == min(6, count / 2), "catalog progress \(count)")
        }
        var incompatible = session
        incompatible.rulesVersion = 9
        try JSONEncoder().encode(incompatible).write(to: dir.appendingPathComponent("session.json"))
        check(store.loadSession()?.rulesVersion == 1, "incompatible uses valid backup")
        // Proven unsolvable and budget exhaustion are not interchangeable.
        var lost = repo.levels[0].initialState
        lost.remainingMoves = 0
        lost.outcome = .outOfMoves
        if case .provenNoSolution = CFVHintSolver.solve(level: repo.levels[0], state: lost) { checks += 1 } else { fatalError("no solution distinction") }
        var changed = repo.levels[0].initialState
        changed.tiles.swapAt(0,1)
        changed.tiles[0] = nil
        if case .budgetExceeded = CFVHintSolver.solve(level: repo.levels[0], state: changed, nodeLimit: 0) { checks += 1 } else { fatalError("budget distinction") }
        if case .cancelled = CFVHintSolver.solve(level: repo.levels[0], state: changed, cancelled: { true }) { checks += 1 } else { fatalError("cancel distinction") }
        // Goal identity travels with swaps; every accepted action removes at least three tiles.
        for level in repo.levels {
            var current = level.initialState
            for action in level.referenceSolution {
                let candidate = CFVEngine.candidate(level, current, action)!
                if action.type == "swap" {
                    check(candidate.0.tiles[action.second!] == current.tiles[action.first!], "tile and target travel together")
                }
                let turn = CFVEngine.apply(level, current, action)!
                check(turn.removedIDs.count >= 3, "minimum match size")
                check(current.tiles.compactMap { $0 }.count - turn.state.tiles.compactMap { $0 }.count == turn.removedIDs.count, "no refill")
                current = turn.state
            }
        }
        var noActions = CFVState(tiles: Array(repeating: nil, count: 36), remainingMoves: 2)
        for cell in [0,1,2] { noActions.tiles[cell] = CFVTile(id: cell, kind: .leaf, isTarget: false) }
        noActions.tiles[35] = CFVTile(id: 35, kind: .circle, isTarget: true)
        // A sparse generated state verifies the terminal no-action branch after a valid fold.
        let sparse = CFVLevel(levelID: "sparse", contentVersion: 1, rulesVersion: 1, learningStage: "test", titleZH: "", titleEN: "", purposeZH: "", purposeEN: "", initialRows: [], targetCells: [35], moveLimit: 2, folds: [right], referenceSolution: [], tutorialCells: [], tutorialCrease: nil)
        noActions.tiles[2] = nil
        noActions.tiles[5] = CFVTile(id: 5, kind: .leaf, isTarget: false)
        check(CFVEngine.apply(sparse, noActions, .fold("right-two"))?.state.outcome == .noActions, "no legal actions failure")
        let witnessData = try Data(contentsOf: root.appendingPathComponent("artifacts/validation/CFV-Level-Design-Witnesses.json"))
        struct Witness: Decodable { let level: Int; let temptingLosingAction: CFVAction? }
        for witness in try JSONDecoder().decode([Witness].self, from: witnessData) {
            guard let action = witness.temptingLosingAction else { continue }
            let level = repo.levels[witness.level - 1]
            let turn = CFVEngine.apply(level, level.initialState, action)!
            if case .provenNoSolution = CFVHintSolver.solve(level: level, state: turn.state, seconds: 3) { checks += 1 }
            else { fatalError("losing branch must be proven unsolvable") }
        }
        // Independently prove the new levels cannot be completed with one fewer move.
        // This deliberately bypasses the reference-path shortcut in the production solver.
        struct ExpansionWitnesses: Decodable {
            let levels: [Witness]
        }
        let expansionData = try Data(contentsOf: root.appendingPathComponent("artifacts/validation/CFV-Expansion-Design-Witnesses.json"))
        let expansion = try JSONDecoder().decode(ExpansionWitnesses.self, from: expansionData)
        check(expansion.levels.count == 12, "twelve expansion witnesses")
        for witness in expansion.levels {
            let advanced = repo.levels[witness.level - 1]
            check(advanced.moveLimit == 4 + (witness.level - 13) / 4, "graduated minimum moves")
            var shorter = advanced.initialState
            shorter.remainingMoves -= 1
            if case .provenNoSolution = CFVHintSolver.solve(level: advanced, state: shorter, nodeLimit: 300_000, seconds: 60) {
                checks += 1
            } else { fatalError("shortest route must be proven: " + advanced.levelID) }
            let trap = CFVEngine.apply(advanced, advanced.initialState, witness.temptingLosingAction!)!
            if case .provenNoSolution = CFVHintSolver.solve(level: advanced, state: trap.state, nodeLimit: 300_000, seconds: 60) {
                checks += 1
            } else { fatalError("advanced losing branch: " + advanced.levelID) }
            check(repo.catalog.creatures.contains { $0.id == repo.catalog.creature(for: advanced).id }, "advanced companion resolves")
            print("PASS \(advanced.levelID): shortest path and losing opening verified")
        }
        // The first twelve boards and save schema stay unchanged. Load an old-format
        // completed journey and an in-progress original level through the expanded repo.
        let legacyDirectory = root.appendingPathComponent("artifacts/validation/legacy-12-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: legacyDirectory, withIntermediateDirectories: true)
        var legacy = CFVProgress()
        legacy.completed = Set(repo.catalog.levelIDs.prefix(12))
        legacy.bestMoves = Dictionary(uniqueKeysWithValues: repo.levels.prefix(12).map { ($0.levelID, $0.referenceSolution.count) })
        legacy.completionIDs = ["existing-completion"]
        legacy.seenTutorials = ["level-01", "level-12"]
        var originalSession = CFVSession(level: repo.levels[4])
        let originalAction = repo.levels[4].referenceSolution[0]
        originalSession.commit(CFVEngine.apply(repo.levels[4], originalSession.state, originalAction)!, action: originalAction)
        try JSONEncoder().encode(legacy).write(to: legacyDirectory.appendingPathComponent("progress.json"))
        try JSONEncoder().encode(originalSession).write(to: legacyDirectory.appendingPathComponent("session.json"))
        let upgradedStore = try CFVSaveStore(directory: legacyDirectory, repository: repo)
        let loadedLegacy = upgradedStore.loadProgress()
        check(loadedLegacy.completed == legacy.completed && loadedLegacy.bestMoves == legacy.bestMoves && loadedLegacy.completionIDs == legacy.completionIDs && loadedLegacy.seenTutorials == legacy.seenTutorials, "legacy progress unchanged")
        check(upgradedStore.loadSession() == originalSession && upgradedStore.notices.isEmpty, "legacy active game unchanged")
        check(repo.catalog.levelIDs.first { !loadedLegacy.completed.contains($0) } == "level-13", "old journey continues at 13")
        check(repo.catalog.creatures.allSatisfy { repo.catalog.stage($0, completed: loadedLegacy.completed) == 2 }, "old collection stays unlocked")
        var advancedSession = CFVSession(level: repo.levels[12])
        for action in repo.levels[12].referenceSolution {
            advancedSession.commit(CFVEngine.apply(repo.levels[12], advancedSession.state, action)!, action: action)
        }
        try upgradedStore.saveSession(advancedSession)
        let expandedProgress = try upgradedStore.reconcile(advancedSession, progress: loadedLegacy)
        check(expandedProgress.completed.count == 13 && repo.catalog.creatures.allSatisfy { repo.catalog.stage($0, completed: expandedProgress.completed) == 2 }, "advanced win preserves six rewards")
        check(upgradedStore.loadSession() == advancedSession, "advanced game save roundtrip")
        // Simulate an interruption after the won-session write but before any progress write.
        let crashDirectory = root.appendingPathComponent("artifacts/validation/crash-fixtures-" + UUID().uuidString)
        let interruptedStore = try CFVSaveStore(directory: crashDirectory, repository: repo)
        try interruptedStore.saveSession(session)
        let recoveryStore = try CFVSaveStore(directory: crashDirectory, repository: repo)
        let recovered = recoveryStore.loadSession()!
        check(recovered.state.outcome == .won, "won session persisted before reward")
        let repaired = try recoveryStore.reconcile(recovered, progress: recoveryStore.loadProgress())
        check(repaired.completed.contains(recovered.levelID) && repaired.completionIDs.count == 1, "crash completion repaired")
        let repeated = try recoveryStore.reconcile(recovered, progress: repaired)
        check(repeated.completed == repaired.completed && repeated.bestMoves == repaired.bestMoves && repeated.completionIDs == repaired.completionIDs, "repeated reconciliation unchanged")
        try recoveryStore.saveProgress(repaired)
        try Data("broken progress".utf8).write(to: crashDirectory.appendingPathComponent("progress.json"))
        check(recoveryStore.loadProgress().completed == repaired.completed, "progress uses independent backup")
        check(recoveryStore.loadSession()?.state.outcome == .won, "progress corruption does not destroy session")
        try Data("broken backup".utf8).write(to: crashDirectory.appendingPathComponent("progress.backup.json"))
        check(recoveryStore.loadProgress().completed.isEmpty && recoveryStore.notices.contains("progress:damaged"), "both corrupt copies report scope")
        let faultFiles = try FileManager.default.contentsOfDirectory(atPath: crashDirectory.path)
        check(faultFiles.contains { $0.hasPrefix("progress-fault-") }, "fault evidence preserved")
        // An incompatible session without a compatible backup restarts only its own level.
        var future = session
        future.contentVersion = 99
        try JSONEncoder().encode(future).write(to: crashDirectory.appendingPathComponent("session.json"))
        let restarted = recoveryStore.loadSession()!
        check(restarted.levelID == level.levelID && restarted.state == level.initialState, "unsupported board version restarts known level")
        check(recoveryStore.notices.contains("session:restarted"), "restart is explicitly reported")
        print("PASS \(checks) checks; all \(repo.levels.count) reference solutions replayed by production Swift.")
    }
}
