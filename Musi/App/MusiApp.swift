import SwiftUI

@main
@MainActor
struct MusiApp: App {
    @StateObject private var library: PlaylistStore
    @StateObject private var offline: OfflineStore
    @StateObject private var player: AudioPlayer

    init() {
        let storage = OfflineStorage()
        let offlineStore = OfflineStore(storage: storage)
        _library = StateObject(wrappedValue: PlaylistStore(storage: storage))
        _offline = StateObject(wrappedValue: offlineStore)
        _player = StateObject(wrappedValue: AudioPlayer(offline: offlineStore))
    }

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(library)
                .environmentObject(offline)
                .environmentObject(player)
        }
    }
}
