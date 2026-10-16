import Foundation

nonisolated enum CFVGardenLight: String, Codable, CaseIterable {
    case amber, dusk, moon
}

nonisolated enum CFVGardenDecoration: String, Codable, CaseIterable {
    case tree, stones, lantern, stars

    var requiredLevel: Int? {
        switch self {
        case .lantern: return 16
        case .stars: return 24
        default: return nil
        }
    }

    func isAvailable(completed: Set<String>) -> Bool {
        guard let level = requiredLevel else { return true }
        return completed.contains(String(format: "level-%02d", level))
    }
}

nonisolated enum CFVGardenBackdrop: String, Codable, CaseIterable {
    case woodland, pond

    func isAvailable(completed: Set<String>) -> Bool {
        self == .woodland || completed.contains("level-20")
    }
}

nonisolated struct CFVGardenResident: Codable, Equatable {
    var creatureID: String
    var size: Double = 0.9
}

/// Version 2 keeps the original single-companion garden without touching puzzle saves.
nonisolated struct CFVGardenComposition: Codable, Equatable {
    static let creatureIDs = ["paper-butterfly", "folded-bird", "paper-fish", "paper-rabbit", "paper-fox", "paper-deer"]
    var residents: [CFVGardenResident?] = [nil, CFVGardenResident(creatureID: "paper-deer"), nil]
    var selectedSlot = 1
    var light: CFVGardenLight = .amber
    var backdrop: CFVGardenBackdrop = .woodland
    var decorations: Set<CFVGardenDecoration> = []

    init() {}

    var creatureID: String {
        get { residents[selectedSlot]?.creatureID ?? residents.compactMap { $0 }.first!.creatureID }
        set { residents[selectedSlot] = CFVGardenResident(creatureID: newValue, size: size) }
    }

    var size: Double {
        get { residents[selectedSlot]?.size ?? 0.9 }
        set { residents[selectedSlot]?.size = min(1, max(0.6, newValue)) }
    }

    var position: Int {
        get { selectedSlot }
        set {
            let destination = min(2, max(0, newValue))
            residents.swapAt(selectedSlot, destination)
            selectedSlot = destination
        }
    }

    var count: Int { residents.compactMap { $0 }.count }

    mutating func removeSelected() {
        guard count > 1 else { return }
        residents[selectedSlot] = nil
        selectedSlot = residents.firstIndex { $0 != nil }!
    }

    func available(completed: Set<String>) -> Self {
        var result = self
        result.decorations = decorations.filter { $0.isAvailable(completed: completed) }
        if !backdrop.isAvailable(completed: completed) { result.backdrop = .woodland }
        return result
    }

    private enum CodingKeys: String, CodingKey {
        case residents, selectedSlot, light, backdrop, decorations
        case creatureID, position, size
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        light = (try? values.decode(CFVGardenLight.self, forKey: .light)) ?? .amber
        backdrop = (try? values.decode(CFVGardenBackdrop.self, forKey: .backdrop)) ?? .woodland
        let rawDecorations = (try? values.decode([String].self, forKey: .decorations)) ?? []
        decorations = Set(rawDecorations.compactMap(CFVGardenDecoration.init(rawValue:)))
        if let saved = try? values.decode([CFVGardenResident?].self, forKey: .residents) {
            residents = Array((saved + [nil, nil, nil]).prefix(3))
            selectedSlot = min(2, max(0, (try? values.decode(Int.self, forKey: .selectedSlot)) ?? 1))
        } else {
            let id = (try? values.decode(String.self, forKey: .creatureID)) ?? "paper-deer"
            selectedSlot = min(2, max(0, (try? values.decode(Int.self, forKey: .position)) ?? 1))
            let size = (try? values.decode(Double.self, forKey: .size)) ?? 0.9
            residents = [nil, nil, nil]
            residents[selectedSlot] = CFVGardenResident(creatureID: id, size: size)
        }
        for index in residents.indices {
            guard var resident = residents[index] else { continue }
            guard Self.creatureIDs.contains(resident.creatureID) else {
                residents[index] = nil
                continue
            }
            resident.size = resident.size.isFinite ? min(1, max(0.6, resident.size)) : 0.9
            residents[index] = resident
        }
        if count == 0 { residents[1] = CFVGardenResident(creatureID: "paper-deer"); selectedSlot = 1 }
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(residents, forKey: .residents)
        try values.encode(selectedSlot, forKey: .selectedSlot)
        try values.encode(light, forKey: .light)
        try values.encode(backdrop, forKey: .backdrop)
        try values.encode(decorations.map(\.rawValue).sorted(), forKey: .decorations)
    }

    static func load(defaults: UserDefaults = .standard) -> Self {
        guard let data = defaults.data(forKey: "CFV.garden"),
              let saved = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        return saved
    }

    func save(defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: "CFV.garden")
    }
}

nonisolated struct CFVGardenAlbum: Codable {
    var scenes: [CFVGardenComposition?] = [nil, nil, nil]

    static func load(defaults: UserDefaults = .standard) -> Self {
        guard let data = defaults.data(forKey: "CFV.garden.album"),
              var saved = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        saved.scenes = Array((saved.scenes + [nil, nil, nil]).prefix(3))
        return saved
    }

    func save(defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: "CFV.garden.album")
    }
}
