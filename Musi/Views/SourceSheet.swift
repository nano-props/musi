import SwiftUI

struct SourceSheet: View {
    @EnvironmentObject private var library: PlaylistStore
    @EnvironmentObject private var player: AudioPlayer
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @State private var isSaving = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://example.com/playlist.json", text: $input)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($inputFocused)
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
            }
            .navigationTitle("歌单设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        Task {
                            isSaving = true
                            let saved = await library.setSource(input)
                            isSaving = false
                            if saved {
                                player.stop()
                                dismiss()
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .onAppear {
                input = library.sourceURL
                if input.isEmpty { inputFocused = true }
            }
        }
    }
}
