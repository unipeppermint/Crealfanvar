import Foundation

nonisolated struct CFVCatalog: Codable {
    let totalLevels: Int
    let totalCreatures: Int
    let levelIDs: [String]
    let creatures: [CFVCreature]

    func stage(_ creature: CFVCreature, completed: Set<String>) -> Int {
        creature.requiredLevelIDs.filter { completed.contains($0) }.count
    }
}

nonisolated struct CFVCreature: Codable {
    let id: String
    let name: String
    let requiredLevelIDs: [String]
    let unlockLevel: Int
}

nonisolated enum CFVContentError: Error { case invalid(String) }

nonisolated struct CFVRepository {
    let catalog: CFVCatalog
    let levels: [CFVLevel]

    init(directory: URL? = nil) throws {
        func url(_ name: String) throws -> URL {
            if let directory {
                let direct = directory.appendingPathComponent(name + ".json")
                if FileManager.default.fileExists(atPath: direct.path) { return direct }
                return directory.appendingPathComponent("Levels/" + name + ".json")
            }
            guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
                throw CFVContentError.invalid(name)
            }
            return url
        }
        let decoder = JSONDecoder()
        catalog = try decoder.decode(CFVCatalog.self, from: Data(contentsOf: url("CFV-Release-Catalog")))
        levels = try (1...catalog.totalLevels).map {
            try decoder.decode(CFVLevel.self, from: Data(contentsOf: url(String(format: "CFV-Level-%02d", $0))))
        }
        try validate()
    }

    func validate() throws {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw CFVContentError.invalid(message) }
        }
        try require(catalog.totalLevels == 12 && catalog.totalCreatures == 6 && levels.map(\.levelID) == catalog.levelIDs, "catalog")
        try require(Set(catalog.levelIDs).count == 12 && catalog.creatures.count == 6, "unique catalog")
        try require(catalog.creatures.flatMap(\.requiredLevelIDs) == catalog.levelIDs, "creature coverage")
        for (index, creature) in catalog.creatures.enumerated() {
            try require(creature.unlockLevel == (index + 1) * 2 && creature.requiredLevelIDs.count == 2, "unlock mapping")
        }
        for level in levels {
            try require(level.initialRows.count == 6 && level.initialRows.allSatisfy { $0.count == 6 && $0.allSatisfy { "LTC.".contains($0) } }, level.levelID + " dimensions")
            try require(level.moveLimit > 0 && level.folds.count <= 2 && level.folds.allSatisfy(\.isValid), "fold geometry")
            try require(Set(level.folds.map(\.creaseID)).count == level.folds.count, "crease IDs")
            try require(!level.targetCells.isEmpty && Set(level.targetCells).count == level.targetCells.count && level.targetCells.allSatisfy { (0..<36).contains($0) && level.initialState.tiles[$0] != nil }, "targets")
            try require(CFVEngine.matches(level.initialState).isEmpty, "initial match")
            var state = level.initialState
            for action in level.referenceSolution {
                guard let turn = CFVEngine.apply(level, state, action) else { throw CFVContentError.invalid("reference " + level.levelID) }
                state = turn.state
            }
            try require(state.outcome == .won, "unsolved " + level.levelID)
            try require(level.tutorialCells.allSatisfy { (0..<36).contains($0) }, "tutorial cells")
            if let crease = level.tutorialCrease { try require(level.folds.contains { $0.creaseID == crease }, "tutorial crease") }
        }
    }
}
