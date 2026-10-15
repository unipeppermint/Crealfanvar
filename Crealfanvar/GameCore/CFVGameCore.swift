import Foundation

nonisolated enum CFVKind: String, Codable, CaseIterable {
    case leaf = "L"
    case triangle = "T"
    case circle = "C"
}

nonisolated struct CFVTile: Codable, Equatable, Hashable {
    let id: Int
    let kind: CFVKind
    let isTarget: Bool
}

nonisolated struct CFVFold: Codable, Equatable, Hashable {
    let creaseID: String
    let axis: String
    let boundary: Int
    let movingSide: String

    func isMoving(_ cell: Int) -> Bool {
        let coordinate = axis == "vertical" ? cell % 6 : cell / 6
        return ["left", "top"].contains(movingSide) ? coordinate < boundary : coordinate >= boundary
    }

    func destination(_ cell: Int) -> Int {
        let row = cell / 6
        let column = cell % 6
        return axis == "vertical" ? row * 6 + 2 * boundary - 1 - column : (2 * boundary - 1 - row) * 6 + column
    }

    var isValid: Bool {
        guard (1...5).contains(boundary),
              axis == "vertical" ? ["left", "right"].contains(movingSide) : axis == "horizontal" && ["top", "bottom"].contains(movingSide) else { return false }
        return (0..<36).filter(isMoving).allSatisfy {
            let coordinate = axis == "vertical" ? $0 % 6 : $0 / 6
            return (0..<6).contains(2 * boundary - 1 - coordinate) && !isMoving(destination($0))
        }
    }
}

nonisolated struct CFVAction: Codable, Equatable, Hashable {
    let type: String
    var first: Int? = nil
    var second: Int? = nil
    var creaseID: String? = nil

    static func swap(_ first: Int, _ second: Int) -> Self {
        Self(type: "swap", first: first, second: second)
    }

    static func fold(_ id: String) -> Self {
        Self(type: "fold", creaseID: id)
    }
}

nonisolated struct CFVLevel: Codable {
    let levelID: String
    let contentVersion: Int
    let rulesVersion: Int
    let learningStage: String
    let titleZH: String
    let titleEN: String
    let purposeZH: String
    let purposeEN: String
    let initialRows: [String]
    let targetCells: [Int]
    let moveLimit: Int
    let folds: [CFVFold]
    let referenceSolution: [CFVAction]
    let tutorialCells: [Int]
    let tutorialCrease: String?

    var initialState: CFVState {
        let symbols = initialRows.flatMap { Array($0) }
        let tiles = symbols.enumerated().map { index, symbol -> CFVTile? in
            guard let kind = CFVKind(rawValue: String(symbol)) else { return nil }
            return CFVTile(id: index, kind: kind, isTarget: targetCells.contains(index))
        }
        return CFVState(tiles: tiles, remainingMoves: moveLimit)
    }
}

nonisolated enum CFVOutcome: String, Codable {
    case playing, won, outOfMoves, noActions
}

nonisolated struct CFVState: Codable, Equatable {
    var tiles: [CFVTile?]
    var remainingMoves: Int
    var revision = 0
    var outcome: CFVOutcome = .playing

    var remainingTargets: Int { tiles.compactMap { $0 }.filter(\.isTarget).count }
}

nonisolated struct CFVProjection {
    let stacks: [[Int]]
    var topCells: [Int?] { stacks.map(\.last) }
}

nonisolated struct CFVTurn {
    let state: CFVState
    let removedIDs: Set<Int>
    let targetDelta: Int
}

nonisolated enum CFVEngine {
    static func projection(_ fold: CFVFold? = nil) -> CFVProjection {
        guard let fold else { return CFVProjection(stacks: (0..<36).map { [$0] }) }
        var stacks = Array(repeating: [Int](), count: 36)
        for cell in 0..<36 where !fold.isMoving(cell) { stacks[cell].append(cell) }
        for cell in 0..<36 where fold.isMoving(cell) { stacks[fold.destination(cell)].append(cell) }
        return CFVProjection(stacks: stacks)
    }

    static func matches(_ state: CFVState, projection: CFVProjection = projection()) -> Set<Int> {
        let surface = projection.topCells.map { $0.flatMap { state.tiles[$0] } }
        var result = Set<Int>()
        for axis in 0..<2 {
            for line in 0..<6 {
                var run = [CFVTile]()
                func flush() {
                    if run.count >= 3 { result.formUnion(run.map(\.id)) }
                    run.removeAll(keepingCapacity: true)
                }
                for position in 0..<6 {
                    let index = axis == 0 ? line * 6 + position : position * 6 + line
                    guard let tile = surface[index] else { flush(); continue }
                    if let last = run.last, last.kind != tile.kind { flush() }
                    run.append(tile)
                }
                flush()
            }
        }
        return result
    }

    static func candidate(_ level: CFVLevel, _ state: CFVState, _ action: CFVAction) -> (CFVState, Set<Int>)? {
        guard state.tiles.count == 36 else { return nil }
        var next = state
        let removed: Set<Int>
        if action.type == "swap" {
            guard let first = action.first, let second = action.second,
                  (0..<36).contains(first), (0..<36).contains(second),
                  abs(first / 6 - second / 6) + abs(first % 6 - second % 6) == 1,
                  state.tiles[first] != nil, state.tiles[second] != nil else { return nil }
            next.tiles.swapAt(first, second)
            removed = matches(next)
        } else if action.type == "fold", let fold = level.folds.first(where: { $0.creaseID == action.creaseID }), fold.isValid {
            removed = matches(next, projection: projection(fold))
        } else { return nil }
        return removed.isEmpty ? nil : (next, removed)
    }

    static func legalActions(_ level: CFVLevel, _ state: CFVState) -> [CFVAction] {
        var actions = level.folds.map { CFVAction.fold($0.creaseID) }
        for cell in 0..<36 {
            if cell % 6 < 5 { actions.append(.swap(cell, cell + 1)) }
            if cell / 6 < 5 { actions.append(.swap(cell, cell + 6)) }
        }
        return actions.filter { candidate(level, state, $0) != nil }
    }

    static func apply(_ level: CFVLevel, _ state: CFVState, _ action: CFVAction) -> CFVTurn? {
        guard state.outcome == .playing, state.remainingMoves > 0,
              let (candidateState, removed) = candidate(level, state, action) else { return nil }
        var next = candidateState
        for cell in 0..<36 where next.tiles[cell].map({ removed.contains($0.id) }) == true {
            next.tiles[cell] = nil
        }
        next.remainingMoves -= 1
        next.revision += 1
        if next.remainingTargets == 0 { next.outcome = .won }
        else if next.remainingMoves == 0 { next.outcome = .outOfMoves }
        else if legalActions(level, next).isEmpty { next.outcome = .noActions }
        return CFVTurn(state: next, removedIDs: removed, targetDelta: state.remainingTargets - next.remainingTargets)
    }
}

nonisolated enum CFVHintResult {
    case foundPath([CFVAction])
    case provenNoSolution
    case budgetExceeded
    case cancelled
}

nonisolated enum CFVHintSolver {
    static func solve(level: CFVLevel, state: CFVState, nodeLimit: Int = 60_000, seconds: Double = 0.5, cancelled: () -> Bool = { false }) -> CFVHintResult {
        // Known paths are replayed from their exact state, never applied to a different board.
        var referenceState = level.initialState
        for index in level.referenceSolution.indices {
            if referenceState.tiles == state.tiles, state.remainingMoves >= level.referenceSolution.count - index {
                return .foundPath(Array(level.referenceSolution[index...]))
            }
            guard let turn = CFVEngine.apply(level, referenceState, level.referenceSolution[index]) else { break }
            referenceState = turn.state
        }
        let deadline = Date().addingTimeInterval(seconds)
        var nodes = 0
        var exhausted = false
        var didCancel = false
        var visited = [String: Int]()
        func search(_ current: CFVState) -> [CFVAction]? {
            if cancelled() { didCancel = true; return nil }
            if current.remainingTargets == 0 { return [] }
            guard current.outcome == .playing else { return nil }
            nodes += 1
            if nodes > nodeLimit || Date() >= deadline { exhausted = true; return nil }
            let key = current.tiles.map { tile in tile.map { $0.kind.rawValue + ($0.isTarget ? "!" : "-") } ?? "__" }.joined()
            if let budget = visited[key], budget >= current.remainingMoves { return nil }
            visited[key] = current.remainingMoves
            let candidates = CFVEngine.legalActions(level, current).compactMap { action -> (CFVAction, CFVTurn)? in
                CFVEngine.apply(level, current, action).map { (action, $0) }
            }.sorted { $0.1.targetDelta > $1.1.targetDelta }
            for (action, turn) in candidates {
                if let path = search(turn.state) { return [action] + path }
                if exhausted || didCancel { return nil }
            }
            return nil
        }
        if let path = search(state) { return .foundPath(path) }
        if didCancel { return .cancelled }
        return exhausted ? .budgetExceeded : .provenNoSolution
    }
}
