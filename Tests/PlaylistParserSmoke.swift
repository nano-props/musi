import Foundation

@main
struct PlaylistParserSmoke {
    static func main() throws {
        let source = URL(string: "https://example.com/music/playlist.json")!

        let object = Data(#"{"schema_version":1,"title":"收藏","songs":[{"title":"曲目 A","artist":"歌手","url":"tracks/a.m4a"},"https://cdn.example.com/b.m4a"]}"#.utf8)
        let parsed = try PlaylistParser.parse(object, sourceURL: source)
        precondition(parsed.title == "收藏")
        precondition(parsed.songs.count == 2)
        precondition(parsed.songs[0].url.absoluteString == "https://example.com/music/tracks/a.m4a")
        precondition(parsed.songs[0].artist == "歌手")
        precondition(parsed.songs[1].title == "b")

        let urlList = Data(#"{"url_list":["https://example.com/one.m4a"]}"#.utf8)
        let parsedURLList = try PlaylistParser.parse(urlList, sourceURL: source)
        precondition(parsedURLList.songs.count == 1)

        let insecure = Data(#"{"songs":["http://example.com/one.m4a"]}"#.utf8)
        do {
            _ = try PlaylistParser.parse(insecure, sourceURL: source)
            fatalError("HTTP URL should have failed")
        } catch PlaylistError.invalidSong(0) {
            // Expected: audio URLs must use HTTPS.
        }

        let futureVersion = Data(#"{"schema_version":2,"songs":["https://example.com/one.m4a"]}"#.utf8)
        do {
            _ = try PlaylistParser.parse(futureVersion, sourceURL: source)
            fatalError("Unknown schema version should have failed")
        } catch PlaylistError.unsupportedVersion {
            // Expected: fail clearly when the remote format changes.
        }

        print("Playlist parser checks passed")
    }
}
