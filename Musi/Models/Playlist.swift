import Foundation

struct Song: Identifiable, Equatable {
    let id: Int
    let title: String
    let artist: String?
    let url: URL
}

struct Playlist {
    let title: String
    let songs: [Song]
}

enum PlaylistError: LocalizedError {
    case invalidSourceURL
    case invalidJSON
    case missingSongs
    case invalidSong(Int)
    case emptyPlaylist
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidSourceURL:
            return "请输入有效的 HTTPS 歌单地址。"
        case .invalidJSON:
            return "歌单不是有效的 JSON。"
        case .missingSongs:
            return "歌单需要包含 songs、tracks 或 url_list 数组。"
        case .invalidSong(let index):
            return "第 \(index + 1) 首歌曲缺少有效的 HTTPS 音频地址。"
        case .emptyPlaylist:
            return "歌单中还没有歌曲。"
        case .httpStatus(let code):
            return "读取歌单失败，服务器返回 HTTP \(code)。"
        }
    }
}

enum PlaylistParser {
    static func parse(_ data: Data, sourceURL: URL) throws -> Playlist {
        let root: Any
        do {
            root = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw PlaylistError.invalidJSON
        }

        let entries: [Any]
        let title: String
        if let object = root as? [String: Any] {
            guard let list = (object["songs"] ?? object["tracks"] ?? object["url_list"]) as? [Any] else {
                throw PlaylistError.missingSongs
            }
            entries = list
            title = nonempty(object["title"] as? String) ?? nonempty(object["name"] as? String) ?? "我的歌单"
        } else if let list = root as? [Any] {
            entries = list
            title = "我的歌单"
        } else {
            throw PlaylistError.missingSongs
        }

        guard !entries.isEmpty else { throw PlaylistError.emptyPlaylist }
        let songs = try entries.enumerated().map { index, entry -> Song in
            let rawURL: String
            let rawTitle: String?
            let artist: String?
            if let value = entry as? String {
                rawURL = value
                rawTitle = nil
                artist = nil
            } else if let value = entry as? [String: Any],
                      let link = (value["url"] ?? value["audio_url"] ?? value["audioUrl"]) as? String {
                rawURL = link
                rawTitle = value["title"] as? String ?? value["name"] as? String
                artist = nonempty(value["artist"] as? String)
            } else {
                throw PlaylistError.invalidSong(index)
            }

            guard let url = URL(string: rawURL, relativeTo: sourceURL)?.absoluteURL,
                  url.scheme?.lowercased() == "https",
                  url.host != nil else {
                throw PlaylistError.invalidSong(index)
            }
            let fallback = url.deletingPathExtension().lastPathComponent.removingPercentEncoding ?? ""
            return Song(id: index,
                        title: nonempty(rawTitle) ?? nonempty(fallback) ?? "歌曲 \(index + 1)",
                        artist: artist,
                        url: url)
        }
        return Playlist(title: title, songs: songs)
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
