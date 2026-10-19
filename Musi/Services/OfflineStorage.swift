import CryptoKit
import Foundation

/// Disk layout for the playlist and media that must survive app relaunches.
struct OfflineStorage {
    enum AssetKind {
        case audio
        case artwork

        var directoryName: String {
            switch self {
            case .audio: "Audio"
            case .artwork: "Artwork"
            }
        }
    }

    private struct PlaylistSnapshot: Codable {
        let sourceURL: String
        let json: Data
    }

    private let root: URL
    private let fileManager = FileManager.default

    init(root: URL = URL.applicationSupportDirectory.appendingPathComponent("Musi", isDirectory: true)) {
        self.root = root
    }

    func loadPlaylist(for sourceURL: URL) -> Data? {
        guard let data = try? Data(contentsOf: root.appendingPathComponent("playlist.json")),
              let snapshot = try? JSONDecoder().decode(PlaylistSnapshot.self, from: data),
              snapshot.sourceURL == sourceURL.absoluteString else { return nil }
        return snapshot.json
    }

    func savePlaylist(_ json: Data, for sourceURL: URL) throws {
        try prepareDirectory(root)
        let snapshot = PlaylistSnapshot(sourceURL: sourceURL.absoluteString, json: json)
        try JSONEncoder().encode(snapshot).write(to: root.appendingPathComponent("playlist.json"), options: .atomic)
    }

    func localURL(for remoteURL: URL, kind: AssetKind) -> URL? {
        let destination = fileURL(for: remoteURL, kind: kind)
        guard fileManager.fileExists(atPath: destination.path),
              let size = try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size > 0 else { return nil }
        return destination
    }

    func saveDownload(at temporaryURL: URL, from remoteURL: URL, kind: AssetKind) throws -> URL {
        let destination = fileURL(for: remoteURL, kind: kind)
        try prepareDirectory(destination.deletingLastPathComponent())
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    func removeMedia() throws {
        for kind in [AssetKind.audio, .artwork] {
            let directory = root.appendingPathComponent(kind.directoryName, isDirectory: true)
            if fileManager.fileExists(atPath: directory.path) {
                try fileManager.removeItem(at: directory)
            }
        }
    }

    private func fileURL(for remoteURL: URL, kind: AssetKind) -> URL {
        let digest = SHA256.hash(data: Data(remoteURL.absoluteString.utf8))
            .map { String(format: "%02x", $0) }.joined()
        let name: String
        switch kind {
        case .audio:
            let ext = remoteURL.pathExtension.lowercased()
            let allowed = CharacterSet.alphanumerics
            let safeExtension = !ext.isEmpty && ext.count <= 8 && ext.unicodeScalars.allSatisfy(allowed.contains)
                ? ext : "m4a"
            name = "\(digest).\(safeExtension)"
        case .artwork:
            name = "\(digest).image"
        }
        return root.appendingPathComponent(kind.directoryName, isDirectory: true)
            .appendingPathComponent(name)
    }

    private func prepareDirectory(_ directory: URL) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableDirectory = directory
        try mutableDirectory.setResourceValues(values)
    }
}
