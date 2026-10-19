import SwiftUI

struct SongArtworkView: View {
    @EnvironmentObject private var offline: OfflineStore
    @State private var image: UIImage?

    let song: Song
    var cornerRadius: CGFloat = 10

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.accentColor.opacity(0.1)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: min(geometry.size.width * 0.38, 100)))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .task(id: song.artworkURL) {
            image = nil
            image = await offline.cacheArtwork(song)
        }
        .onChange(of: offline.artworkRevision) { _, _ in
            image = offline.cachedArtwork(for: song)
        }
        .accessibilityHidden(true)
    }
}
