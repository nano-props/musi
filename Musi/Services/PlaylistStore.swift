import Combine
import Foundation

@MainActor
final class PlaylistStore: ObservableObject {
    @Published private(set) var sourceURL: String
    @Published private(set) var playlist: Playlist?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let key = "playlistSourceURL"

    init() {
        sourceURL = UserDefaults.standard.string(forKey: key) ?? ""
    }

    func setSource(_ rawValue: String) async -> Bool {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.validURL(value) != nil else {
            errorMessage = PlaylistError.invalidSourceURL.localizedDescription
            return false
        }
        sourceURL = value
        UserDefaults.standard.set(value, forKey: key)
        playlist = nil
        await refresh()
        return true
    }

    func refresh() async {
        guard let url = Self.validURL(sourceURL) else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
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
            playlist = try PlaylistParser.parse(data, sourceURL: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    static func validURL(_ value: String) -> URL? {
        guard let url = URL(string: value),
              url.scheme?.lowercased() == "https",
              url.host != nil else { return nil }
        return url
    }
}
