import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var library: PlaylistStore
    @EnvironmentObject private var offline: OfflineStore
    @EnvironmentObject private var player: AudioPlayer
    @State private var showingSource = false
    @State private var showingPlayer = false

    var body: some View {
        NavigationStack {
            Group {
                if library.sourceURL.isEmpty {
                    ContentUnavailableView {
                        Label("添加你的歌单", systemImage: "music.note.list")
                    } description: {
                        Text("输入歌单 JSON 的 HTTPS 地址，开始播放你的音乐。")
                    } actions: {
                        Button("配置歌单地址") { showingSource = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else if library.isLoading && library.playlist == nil {
                    ProgressView("正在载入歌单…")
                } else if let playlist = library.playlist {
                    List {
                        if let error = library.errorMessage {
                            Section {
                                HStack(spacing: 10) {
                                    Image(systemName: "exclamationmark.circle")
                                        .foregroundStyle(.orange)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("歌单仍可使用").font(.subheadline.weight(.semibold))
                                        Text(error).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 4)
                                    Button("重试") { Task { await library.refresh() } }
                                        .font(.subheadline.weight(.semibold))
                                }
                            }
                        }
                        Section {
                            ForEach(playlist.songs) { song in
                                HStack(spacing: 8) {
                                    Button {
                                        player.play(song, from: playlist)
                                    } label: {
                                        SongRow(song: song, isCurrent: player.currentSong?.url == song.url)
                                    }
                                    .buttonStyle(.plain)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    if offline.isAudioCached(song) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                            .frame(width: 44, height: 44)
                                            .accessibilityLabel("已下载，可离线播放")
                                    } else if offline.downloadingAudio.contains(song.url) {
                                        ProgressView()
                                            .frame(width: 44, height: 44)
                                            .accessibilityLabel("正在下载")
                                    } else {
                                        Button {
                                            offline.downloadSong(song)
                                        } label: {
                                            Image(systemName: "arrow.down.circle")
                                                .frame(width: 44, height: 44)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("下载\(song.title)")
                                    }
                                }
                            }
                        } header: {
                            Text(playlist.title)
                        } footer: {
                            Text(offline.isDownloadingAll
                                 ? "正在下载 \(offline.completedDownloads)/\(offline.totalDownloads) 首"
                                 : "已下载 \(offline.cachedSongCount(in: playlist))/\(playlist.songs.count) 首，可离线播放")
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable { await library.refresh() }
                } else {
                    ContentUnavailableView {
                        Label("无法载入歌单", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(library.errorMessage ?? "请检查网络连接和歌单地址。")
                    } actions: {
                        Button("重试") { Task { await library.refresh() } }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("音乐")
            .toolbar {
                if let playlist = library.playlist {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            offline.downloadAll(playlist)
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                        }
                        .disabled(offline.isDownloadingAll)
                        .accessibilityLabel("下载全部歌曲")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSource = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("歌单设置")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if player.currentSong != nil {
                    MiniPlayer(showingPlayer: $showingPlayer)
                }
            }
            .sheet(isPresented: $showingSource) { SourceSheet() }
            .sheet(isPresented: $showingPlayer) { NowPlayingView() }
            .alert("播放失败", isPresented: Binding(
                get: { player.errorMessage != nil },
                set: { if !$0 { player.errorMessage = nil } }
            )) {
                Button("好", role: .cancel) { player.errorMessage = nil }
            } message: {
                Text(player.errorMessage ?? "")
            }
            .alert("下载失败", isPresented: Binding(
                get: { offline.errorMessage != nil },
                set: { if !$0 { offline.errorMessage = nil } }
            )) {
                Button("好", role: .cancel) { offline.errorMessage = nil }
            } message: {
                Text(offline.errorMessage ?? "")
            }
            .task {
                if library.sourceURL.isEmpty {
                    showingSource = true
                } else {
                    await library.refresh()
                }
            }
        }
    }
}

private struct SongRow: View {
    let song: Song
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 14) {
            SongArtworkView(song: song)
                .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(song.title).font(.body.weight(isCurrent ? .semibold : .regular))
                    .lineLimit(1)
                if let artist = song.artist {
                    Text(artist).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if isCurrent { Image(systemName: "speaker.wave.2.fill").font(.caption).foregroundStyle(.tint) }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 3)
    }
}

private struct MiniPlayer: View {
    @EnvironmentObject private var player: AudioPlayer
    @Binding var showingPlayer: Bool

    var body: some View {
        HStack(spacing: 12) {
            Button { showingPlayer = true } label: {
                HStack(spacing: 12) {
                    if let song = player.currentSong {
                        SongArtworkView(song: song)
                            .frame(width: 44, height: 44)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.currentSong?.title ?? "")
                            .font(.subheadline.weight(.semibold)).lineLimit(1)
                        Text(player.currentSong?.artist ?? "正在播放")
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            Button { player.toggle() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3).frame(width: 42, height: 42)
            }
            .accessibilityLabel(player.isPlaying ? "暂停" : "播放")
            Button { player.next() } label: {
                Image(systemName: "forward.end.fill")
                    .font(.title3).frame(width: 36, height: 42)
            }
            .accessibilityLabel("下一首")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }
}
