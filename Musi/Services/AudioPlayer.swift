import AVFoundation
import Combine
import MediaPlayer
import UIKit

@MainActor
final class AudioPlayer: ObservableObject {
    @Published private(set) var currentSong: Song?
    @Published private(set) var isPlaying = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published var errorMessage: String?

    private let player = AVPlayer()
    private let offline: OfflineStore
    private var currentArtwork: UIImage?
    private var songs: [Song] = []
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var statusObserver: NSKeyValueObservation?
    private var audioCacheTask: Task<Void, Never>?
    private var artworkTask: Task<Void, Never>?

    init(offline: OfflineStore) {
        self.offline = offline
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.elapsed = time.seconds.isFinite ? max(0, time.seconds) : 0
                let length = self.player.currentItem?.duration.seconds ?? 0
                self.duration = length.isFinite ? max(0, length) : 0
                self.updateNowPlayingInfo()
            }
        }
        configureRemoteCommands()
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }

    func play(_ song: Song, from playlist: Playlist) {
        if currentSong?.url == song.url {
            resume()
            return
        }
        songs = playlist.songs
        audioCacheTask?.cancel()
        artworkTask?.cancel()
        currentSong = song
        currentArtwork = nil
        elapsed = 0
        duration = 0
        errorMessage = nil

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            errorMessage = "无法启动音频会话：\(error.localizedDescription)"
            return
        }

        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        let localURL = offline.localAudioURL(for: song)
        let item = AVPlayerItem(url: localURL ?? song.url)
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.next() }
        }
        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            Task { @MainActor [weak self] in
                self?.isPlaying = false
                self?.errorMessage = item.error?.localizedDescription ?? "音频播放失败，请检查歌曲地址。"
            }
        }
        player.replaceCurrentItem(with: item)
        resume()
        if localURL == nil {
            audioCacheTask = Task {
                guard !Task.isCancelled else { return }
                try? await offline.cacheAudio(song)
            }
        }
        artworkTask = Task { [weak self] in
            guard let self else { return }
            guard !Task.isCancelled else { return }
            let artwork = await self.offline.cacheArtwork(song)
            guard self.currentSong?.url == song.url else { return }
            self.currentArtwork = artwork
            self.updateNowPlayingInfo()
        }
    }

    func toggle() {
        isPlaying ? pause() : resume()
    }

    func pause() {
        player.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }

    func resume() {
        guard currentSong != nil else { return }
        player.play()
        isPlaying = true
        updateNowPlayingInfo()
    }

    func next() {
        guard let currentSong,
              let index = songs.firstIndex(where: { $0.url == currentSong.url }),
              index + 1 < songs.count else {
            pause()
            seek(to: 0)
            return
        }
        play(songs[index + 1], from: Playlist(title: "", songs: songs))
    }

    func previous() {
        if elapsed > 3 {
            seek(to: 0)
            return
        }
        guard let currentSong,
              let index = songs.firstIndex(where: { $0.url == currentSong.url }),
              index > 0 else {
            seek(to: 0)
            return
        }
        play(songs[index - 1], from: Playlist(title: "", songs: songs))
    }

    func seek(to seconds: TimeInterval) {
        guard seconds.isFinite else { return }
        player.seek(to: CMTime(seconds: max(0, seconds), preferredTimescale: 600))
        elapsed = max(0, seconds)
        updateNowPlayingInfo()
    }

    func stop() {
        audioCacheTask?.cancel()
        artworkTask?.cancel()
        audioCacheTask = nil
        artworkTask = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        statusObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        songs = []
        currentSong = nil
        currentArtwork = nil
        isPlaying = false
        elapsed = 0
        duration = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func updateNowPlayingInfo() {
        guard let currentSong else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: currentSong.title,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        if let artist = currentSong.artist { info[MPMediaItemPropertyArtist] = artist }
        if duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }
        if let currentArtwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: currentArtwork.size) { _ in currentArtwork }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func configureRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.resume() }
            return .success
        }
        commands.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.pause() }
            return .success
        }
        commands.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.next() }
            return .success
        }
        commands.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.previous() }
            return .success
        }
        commands.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor [weak self] in self?.seek(to: event.positionTime) }
            return .success
        }
    }
}
