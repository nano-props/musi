import SwiftUI

@main
struct MusiApp: App {
    @StateObject private var library = PlaylistStore()
    @StateObject private var player = AudioPlayer()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(library)
                .environmentObject(player)
        }
    }
}
