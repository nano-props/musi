import Combine
import Foundation
import UIKit

enum OfflineError: LocalizedError {
    case httpStatus(Int)
    case emptyFile
    case invalidMedia
    case artworkTooLarge

    var errorDescription: String? {
        switch self {
        case .httpStatus(let code): "下载失败，服务器返回 HTTP \(code)。"
        case .emptyFile: "下载的文件是空的。"
        case .invalidMedia: "下载的文件不是可用的音频或图片。"
        case .artworkTooLarge: "歌曲图片不能超过 15 MB。"
        }
    }
}

@MainActor
final class OfflineStore: ObservableObject {
    @Published private(set) var downloadingAudio: Set<URL> = []
    @Published private(set) var isDownloadingAll = false
    @Published private(set) var completedDownloads = 0
    @Published private(set) var totalDownloads = 0
    @Published private(set) var revision = 0
    @Published var errorMessage: String?

    let storage: OfflineStorage
    private var audioTasks: [URL: Task<URL, Error>] = [:]
    private var artworkTasks: [URL: Task<URL, Error>] = [:]
    private var bulkTask: Task<Void, Never>?
    private var generation = 0

    init(storage: OfflineStorage = OfflineStorage()) {
        self.storage = storage
    }

    func localAudioURL(for song: Song) -> URL? {
        storage.localURL(for: song.url, kind: .audio)
    }

    func isAudioCached(_ song: Song) -> Bool {
        localAudioURL(for: song) != nil
    }

    func cachedSongCount(in playlist: Playlist) -> Int {
        playlist.songs.filter(isAudioCached).count
    }

    func cacheAudio(_ song: Song) async throws {
        if isAudioCached(song) { return }
        if let task = audioTasks[song.url] {
            _ = try await task.value
            return
        }

        downloadingAudio.insert(song.url)
        let startGeneration = generation
        let task = Task { [storage] in
            let temporaryURL = try await Self.download(song.url)
            try Task.checkCancellation()
            return try storage.saveDownload(at: temporaryURL, from: song.url, kind: .audio)
        }
        audioTasks[song.url] = task
        defer {
            if generation == startGeneration {
                audioTasks[song.url] = nil
                downloadingAudio.remove(song.url)
            }
        }
        _ = try await task.value
        if generation == startGeneration { revision += 1 }
    }

    func cacheArtwork(_ song: Song) async -> UIImage? {
        guard let remoteURL = song.artworkURL else { return nil }
        if let localURL = storage.localURL(for: remoteURL, kind: .artwork),
           let image = UIImage(contentsOfFile: localURL.path) {
            return image
        }
        do {
            if let task = artworkTasks[remoteURL] {
                return UIImage(contentsOfFile: try await task.value.path)
            }
            let startGeneration = generation
            let task = Task { [storage] in
                let temporaryURL = try await Self.download(remoteURL)
                try Task.checkCancellation()
                let size = try temporaryURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 15 * 1024 * 1024 else { throw OfflineError.artworkTooLarge }
                guard UIImage(contentsOfFile: temporaryURL.path) != nil else {
                    throw OfflineError.invalidMedia
                }
                return try storage.saveDownload(at: temporaryURL, from: remoteURL, kind: .artwork)
            }
            artworkTasks[remoteURL] = task
            defer {
                if generation == startGeneration { artworkTasks[remoteURL] = nil }
            }
            let localURL = try await task.value
            if generation == startGeneration { revision += 1 }
            return UIImage(contentsOfFile: localURL.path)
        } catch {
            return nil
        }
    }

    func downloadSong(_ song: Song) {
        let startGeneration = generation
        Task {
            guard generation == startGeneration else { return }
            do {
                try await cacheAudio(song)
                _ = await cacheArtwork(song)
            } catch {
                if generation == startGeneration && !(error is CancellationError) {
                    errorMessage = "无法下载《\(song.title)》：\(error.localizedDescription)"
                }
            }
        }
    }

    func downloadAll(_ playlist: Playlist) {
        guard !isDownloadingAll else { return }
        isDownloadingAll = true
        totalDownloads = playlist.songs.count
        completedDownloads = 0
        errorMessage = nil
        let startGeneration = generation
        bulkTask = Task {
            var failures = 0
            for song in playlist.songs {
                guard !Task.isCancelled, generation == startGeneration else { break }
                do {
                    try await cacheAudio(song)
                    _ = await cacheArtwork(song)
                } catch {
                    failures += 1
                }
                if generation == startGeneration { completedDownloads += 1 }
            }
            guard generation == startGeneration else { return }
            isDownloadingAll = false
            bulkTask = nil
            if failures > 0 {
                errorMessage = "\(failures) 首歌曲未能下载，请检查网络后重试。"
            }
        }
    }

    func clearMedia() throws {
        cancelDownloads()
        try storage.removeMedia()
        errorMessage = nil
        revision += 1
    }

    func cancelDownloads() {
        generation += 1
        bulkTask?.cancel()
        bulkTask = nil
        for task in audioTasks.values { task.cancel() }
        for task in artworkTasks.values { task.cancel() }
        audioTasks.removeAll()
        artworkTasks.removeAll()
        downloadingAudio.removeAll()
        isDownloadingAll = false
        completedDownloads = 0
        totalDownloads = 0
    }

    private static func download(_ url: URL) async throws -> URL {
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode) else {
            throw OfflineError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        let size = try temporaryURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0 else { throw OfflineError.emptyFile }
        guard response.mimeType?.hasPrefix("text/") != true,
              response.mimeType != "application/json" else { throw OfflineError.invalidMedia }
        return temporaryURL
    }
}
