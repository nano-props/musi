import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject private var player: AudioPlayer
    @Environment(\.dismiss) private var dismiss
    @State private var scrubPosition: Double = 0
    @State private var isScrubbing = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer(minLength: 24)
                GeometryReader { geometry in
                    if let song = player.currentSong {
                        let size = min(geometry.size.width, geometry.size.height)
                        SongArtworkView(song: song, cornerRadius: 24)
                            .frame(width: size, height: size)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .padding(.horizontal, 34)
                Spacer(minLength: 32)
                VStack(alignment: .leading, spacing: 8) {
                    Text(player.currentSong?.title ?? "")
                        .font(.title2.bold())
                        .lineLimit(2)
                    Text(player.currentSong?.artist ?? "未知艺术家")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 34)
                .padding(.top, 30)

                VStack(spacing: 0) {
                    Slider(value: $scrubPosition, in: 0...max(player.duration, 1)) { editing in
                        isScrubbing = editing
                        if !editing { player.seek(to: scrubPosition) }
                    }
                    .disabled(player.duration <= 0)
                    HStack {
                        Text(timeString(isScrubbing ? scrubPosition : player.elapsed))
                        Spacer()
                        Text("−" + timeString(max(0, player.duration - (isScrubbing ? scrubPosition : player.elapsed))))
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 34)
                .padding(.top, 26)

                HStack(spacing: 56) {
                    Button { player.previous() } label: {
                        Image(systemName: "backward.end.fill")
                            .font(.system(size: 27))
                    }
                    .accessibilityLabel("上一首")
                    Button { player.toggle() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 42))
                            .frame(width: 70, height: 70)
                    }
                    .accessibilityLabel(player.isPlaying ? "暂停" : "播放")
                    Button { player.next() } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 27))
                    }
                    .accessibilityLabel("下一首")
                }
                .buttonStyle(.plain)
                .padding(.top, 30)
                Spacer(minLength: 30)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { Text("正在播放").font(.subheadline.weight(.semibold)) }
                ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } }
            }
            .onReceive(player.$elapsed) { value in
                if !isScrubbing { scrubPosition = value }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        let value = Int(seconds.isFinite ? max(0, seconds) : 0)
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}
