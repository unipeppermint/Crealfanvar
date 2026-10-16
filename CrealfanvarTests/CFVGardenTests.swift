import Foundation

@main
struct CFVGardenTests {
    static func main() throws {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            checks += 1
        }
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        let oldData = Data(#"{"creatureID":"paper-fox","light":"moon","position":2,"size":0.68}"#.utf8)
        var garden = try decoder.decode(CFVGardenComposition.self, from: oldData)
        check(garden.count == 1 && garden.residents[2]?.creatureID == "paper-fox", "legacy companion and placement")
        check(garden.light == .moon && garden.size == 0.68, "legacy lighting and size")
        garden.selectedSlot = 0
        garden.creatureID = "paper-butterfly"
        garden.size = 0.7
        garden.selectedSlot = 1
        garden.creatureID = "paper-deer"
        check(garden.count == 3, "three independent companions")
        garden.position = 2
        check(garden.residents[1]?.creatureID == "paper-fox" && garden.creatureID == "paper-deer", "occupied placement swaps without losing a companion")
        garden.removeSelected()
        check(garden.count == 2 && garden.residents[2] == nil, "remove only selected companion")
        garden.removeSelected()
        garden.removeSelected()
        check(garden.count == 1, "always retain one companion")
        garden.decorations = Set(CFVGardenDecoration.allCases)
        garden.backdrop = .pond
        let saved = try decoder.decode(CFVGardenComposition.self, from: encoder.encode(garden))
        check(saved == garden, "full scene codable roundtrip")
        for count in [0, 12, 15, 16, 19, 20, 23, 24] {
            let completed = Set((0..<count).map { String(format: "level-%02d", $0 + 1) })
            let available = garden.available(completed: completed)
            check(available.decorations.contains(.tree) && available.decorations.contains(.stones), "free props")
            check(available.decorations.contains(.lantern) == (count >= 16), "lantern boundary")
            check((available.backdrop == .pond) == (count >= 20), "pond boundary")
            check(available.decorations.contains(.stars) == (count >= 24), "star boundary")
            check(available.residents == garden.residents, "rewards do not gate companions")
        }
        let invalid = Data(#"{"residents":[{"creatureID":"unknown","size":9},null,{"creatureID":"paper-fish","size":-9},{"creatureID":"paper-deer","size":1}],"selectedSlot":99,"light":"unknown","decorations":["tree","future"],"backdrop":"future"}"#.utf8)
        let repaired = try decoder.decode(CFVGardenComposition.self, from: invalid)
        check(repaired.residents.count == 3 && repaired.count == 1, "unknown creature removed and count bounded")
        check(repaired.position == 2 && repaired.size == 0.6, "saved ranges repaired")
        check(repaired.light == .amber && repaired.backdrop == .woodland, "unknown scenery defaults")
        check(repaired.decorations == [.tree], "known props preserved")
        let empty = try decoder.decode(CFVGardenComposition.self, from: Data(#"{"residents":[],"selectedSlot":-8}"#.utf8))
        check(empty.count == 1 && empty.creatureID == "paper-deer", "empty save has usable default")
        var album = CFVGardenAlbum()
        album.scenes[0] = garden
        album.scenes[2] = repaired
        let decodedAlbum = try decoder.decode(CFVGardenAlbum.self, from: encoder.encode(album))
        check(decodedAlbum.scenes == album.scenes, "three saved scenes roundtrip")
        check(decodedAlbum.scenes[0]?.available(completed: []).decorations == [.tree, .stones], "loading scene cannot bypass reward gates")
        print("PASS \(checks) garden migration, arrangement, reward and saved-scene checks")
    }
}
