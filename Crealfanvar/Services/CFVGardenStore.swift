import Foundation

/// The freely arranged garden is independent of earned puzzle progress.
struct CFVGardenComposition: Codable {
    var creatureID = "paper-deer"
    var light: CFVGardenLight = .amber
    var position = 1
    var size: Double = 0.9

    static func load() -> CFVGardenComposition {
        guard let data = UserDefaults.standard.data(forKey: "CFV.garden"),
              var saved = try? JSONDecoder().decode(Self.self, from: data) else {
            return Self()
        }
        saved.position = min(2, max(0, saved.position))
        saved.size = min(1, max(0.6, saved.size))
        return saved
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: "CFV.garden")
    }
}
