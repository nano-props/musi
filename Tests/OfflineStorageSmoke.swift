import Foundation

@main
struct OfflineStorageSmoke {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MusiOfflineStorageSmoke-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = OfflineStorage(root: root)
        let source = URL(string: "https://example.com/playlist.json")!
        let otherSource = URL(string: "https://example.com/other.json")!
        let json = Data(#"{"songs":["https://example.com/song.m4a"]}"#.utf8)

        try storage.savePlaylist(json, for: source)
        precondition(storage.loadPlaylist(for: source) == json)
        precondition(storage.loadPlaylist(for: otherSource) == nil)

        let songURL = URL(string: "https://example.com/song.m4a?version=1")!
        let temporary = root.deletingLastPathComponent().appendingPathComponent(UUID().uuidString)
        try Data("audio bytes".utf8).write(to: temporary)
        let saved = try storage.saveDownload(at: temporary, from: songURL, kind: .audio)
        precondition(storage.localURL(for: songURL, kind: .audio) == saved)
        precondition(storage.localURL(for: URL(string: "https://example.com/song.m4a?version=2")!, kind: .audio) == nil)

        let artworkURL = URL(string: "https://example.com/cover.jpg")!
        let artworkTemporary = root.deletingLastPathComponent().appendingPathComponent(UUID().uuidString)
        try Data("image bytes".utf8).write(to: artworkTemporary)
        let artworkSaved = try storage.saveDownload(at: artworkTemporary, from: artworkURL, kind: .artwork)
        precondition(storage.localURL(for: artworkURL, kind: .artwork) == artworkSaved)

        try storage.removeMedia()
        precondition(storage.localURL(for: songURL, kind: .audio) == nil)
        precondition(storage.localURL(for: artworkURL, kind: .artwork) == nil)
        precondition(storage.loadPlaylist(for: source) == json)
        print("Offline storage checks passed")
    }
}
