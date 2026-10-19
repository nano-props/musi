import SwiftUI

struct SourceSheet: View {
    @EnvironmentObject private var library: PlaylistStore
    @EnvironmentObject private var offline: OfflineStore
    @EnvironmentObject private var player: AudioPlayer
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @State private var showingClearConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://example.com/playlist.json", text: $input)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                } header: {
                    Text("歌单地址")
                } footer: {
                    Text("填写返回 JSON 的 HTTPS 链接。保存后会自动载入，之后每次打开 App 也会刷新。")
                }

                if let error = library.errorMessage,
                   PlaylistStore.validURL(input.trimmingCharacters(in: .whitespacesAndNewlines)) == nil {
                    Section {
                        Label(error, systemImage: "exclamationmark.circle")
                            .foregroundStyle(.red)
                    }
                }

                if !library.sourceURL.isEmpty {
                    Section {
                        Text("当前歌单已下载 \(library.playlist.map(offline.cachedSongCount(in:)) ?? 0) 首歌曲")
                        Button("清除已下载音频和图片", role: .destructive) {
                            showingClearConfirmation = true
                        }
                    } header: {
                        Text("离线存储")
                    } footer: {
                        Text("播放歌曲时会自动下载。也可以在歌单中下载单曲或全部歌曲；下载时请保持 App 打开。")
                    }
                }
            }
            .navigationTitle("歌单设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        let previousURL = library.sourceURL
                        let saved = library.setSource(input)
                        if saved {
                            if library.sourceURL != previousURL { offline.cancelDownloads() }
                            player.stop()
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                input = library.sourceURL
            }
            .confirmationDialog("清除已下载的音频和图片？", isPresented: $showingClearConfirmation) {
                Button("清除离线文件", role: .destructive) {
                    player.stop()
                    do {
                        try offline.clearMedia()
                    } catch {
                        offline.errorMessage = "无法清除离线文件：\(error.localizedDescription)"
                    }
                }
            }
            .alert("离线存储出错", isPresented: Binding(
                get: { offline.errorMessage != nil },
                set: { if !$0 { offline.errorMessage = nil } }
            )) {
                Button("好", role: .cancel) { offline.errorMessage = nil }
            } message: {
                Text(offline.errorMessage ?? "")
            }
        }
    }
}
