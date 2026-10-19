import Combine
import Foundation

@MainActor
final class PlaylistStore: ObservableObject {
    @Published private(set) var sourceURL: String
    @Published private(set) var playlist: Playlist?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let key = "playlistSourceURL"
    private let legacyDemoURL = "https://raw.githubusercontent.com/nano-props/musi/main/examples/playlist.json"
    private let storage: OfflineStorage
    private var refreshID = 0

    init(storage: OfflineStorage = OfflineStorage()) {
        self.storage = storage
        let savedURL = UserDefaults.standard.string(forKey: key) ?? ""
        if savedURL == legacyDemoURL {
            UserDefaults.standard.removeObject(forKey: key)
            sourceURL = ""
        } else {
            sourceURL = savedURL
        }
        if let url = Self.validURL(sourceURL),
           let data = storage.loadPlaylist(for: url) {
            playlist = try? PlaylistParser.parse(data, sourceURL: url)
        }
    }

    func setSource(_ rawValue: String) -> Bool {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.validURL(value) != nil else {
            errorMessage = PlaylistError.invalidSourceURL.localizedDescription
            return false
        }
        let changed = sourceURL != value
        sourceURL = value
        UserDefaults.standard.set(value, forKey: key)
        if changed, let url = Self.validURL(value),
           let data = storage.loadPlaylist(for: url) {
            playlist = try? PlaylistParser.parse(data, sourceURL: url)
        } else if changed {
            playlist = nil
        }
        isLoading = true
        Task { await refresh() }
        return true
    }

    func refresh() async {
        guard let url = Self.validURL(sourceURL) else { return }
        refreshID += 1
        let requestID = refreshID
        isLoading = true
        errorMessage = nil
        defer {
            if requestID == refreshID { isLoading = false }
        }
        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw PlaylistError.invalidJSON
            }
            guard (200..<300).contains(response.statusCode) else {
                throw PlaylistError.httpStatus(response.statusCode)
            }
            let updated = try PlaylistParser.parse(data, sourceURL: url)
            guard requestID == refreshID else { return }
            playlist = updated
            do {
                try storage.savePlaylist(data, for: url)
            } catch {
                errorMessage = "歌单已加载，但无法保存离线副本：\(error.localizedDescription)"
            }
        } catch {
            if requestID == refreshID { errorMessage = error.localizedDescription }
        }
    }

    static func validURL(_ value: String) -> URL? {
        guard let url = URL(string: value),
              url.scheme?.lowercased() == "https",
              url.host != nil else { return nil }
        return url
    }
}
