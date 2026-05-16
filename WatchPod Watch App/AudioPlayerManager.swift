import Foundation
import AVFoundation
import MediaPlayer
import Combine

@MainActor
final class AudioPlayerManager: NSObject, ObservableObject {
    @Published private(set) var nowPlaying: URL?
    @Published private(set) var isPlaying: Bool = false
    @Published var errorMessage: String?

    @Published private(set) var queue: [URL] = []
    @Published private(set) var currentIndex: Int = 0
    @Published var loopEnabled: Bool = true
    @Published private(set) var contextLabel: String = ""
    @Published private(set) var currentOutputName: String = "未接続"
    @Published private(set) var diagnosticLog: String = ""

    private var player: AVPlayer?
    private var currentItem: AVPlayerItem?
    private var routeObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var mediaResetObserver: NSObjectProtocol?
    private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
    private var rateObservation: NSKeyValueObservation?
    private var remoteCommandsSetup = false

    func recordScenePhase(_ phase: String) {
        diag("ScenePhase=\(phase) rate=\(player?.rate ?? -1)")
    }

    private func diag(_ msg: String) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        diagnosticLog = "[\(ts)] \(msg)\n" + diagnosticLog.split(separator: "\n").prefix(20).joined(separator: "\n")
        print("AUDIO_DIAG \(msg)")
    }

    func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .default,
                policy: .longFormAudio,
                options: []
            )
        } catch {
            errorMessage = "AudioSession失敗: \(error.localizedDescription)"
        }
        refreshOutputName()
        if routeObserver == nil {
            routeObserver = NotificationCenter.default.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.refreshOutputName()
                    if let reasonRaw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                       let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRaw) {
                        self.diag("Route changed reason=\(reasonRaw)")
                        // 新デバイス接続時、または route 設定変更時に再開を試す
                        if reason == .newDeviceAvailable || reason == .routeConfigurationChange {
                            if self.isPlaying || self.player?.rate == 0 {
                                await self.tryResumeAfterInterruption()
                            }
                        }
                    }
                }
            }
        }
        if interruptionObserver == nil {
            interruptionObserver = NotificationCenter.default.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                Task { @MainActor in
                    guard let self = self,
                          let typeRaw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                          let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }
                    switch type {
                    case .began:
                        self.diag("Interruption began")
                    case .ended:
                        let optionsRaw = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                        let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
                        self.diag("Interruption ended shouldResume=\(options.contains(.shouldResume))")
                        if options.contains(.shouldResume) {
                            await self.tryResumeAfterInterruption()
                        } else {
                            await self.tryResumeAfterInterruption()
                        }
                    @unknown default:
                        self.diag("Interruption unknown")
                    }
                }
            }
        }
        if mediaResetObserver == nil {
            mediaResetObserver = NotificationCenter.default.addObserver(
                forName: AVAudioSession.mediaServicesWereResetNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.diag("Media services reset!") }
            }
        }
        setupRemoteCommandsIfNeeded()
        diag("AudioSession configured: \(AVAudioSession.sharedInstance().category.rawValue)")
    }

    private func setupRemoteCommandsIfNeeded() {
        guard !remoteCommandsSetup else { return }
        remoteCommandsSetup = true
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.diag("Remote: play")
                await self?.tryResumeAfterInterruption()
            }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.diag("Remote: pause")
                self?.pause()
            }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.diag("Remote: toggle")
                self?.togglePlayPause()
            }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.diag("Remote: next")
                self?.next()
            }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.diag("Remote: prev")
                self?.previous()
            }
            return .success
        }
        center.stopCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.diag("Remote: stop")
                self?.stop()
            }
            return .success
        }
    }

    private func tryResumeAfterInterruption() async {
        guard player != nil, nowPlaying != nil else {
            diag("resume skipped: no player/item")
            return
        }
        let session = AVAudioSession.sharedInstance()
        do {
            let activated = try await session.activate(options: [])
            diag("resume activate=\(activated)")
            if activated {
                player?.play()
                isPlaying = true
                updateNowPlayingInfo()
                diag("resume play() called")
            }
        } catch {
            diag("resume failed: \(error.localizedDescription)")
        }
    }

    private func refreshOutputName() {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        currentOutputName = outputs.first?.portName ?? "未接続"
    }

    func presentOutputPicker() async {
        let session = AVAudioSession.sharedInstance()
        do {
            let activated = try await session.activate(options: [])
            await MainActor.run {
                refreshOutputName()
                if !activated {
                    errorMessage = "出力先が選ばれませんでした。Watch のサイドボタン長押し → AirPlay で選んでください。"
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "出力先選択エラー: \(error.localizedDescription)"
            }
        }
    }

    func play(url: URL) {
        queue = [url]
        currentIndex = 0
        contextLabel = ""
        playCurrent()
    }

    func playPlaylist(urls: [URL], startAt: Int = 0, label: String) {
        guard !urls.isEmpty else { return }
        queue = urls
        currentIndex = max(0, min(startAt, urls.count - 1))
        contextLabel = label
        playCurrent()
    }

    private func playCurrent() {
        guard queue.indices.contains(currentIndex) else { return }
        let url = queue[currentIndex]
        Task {
            await activateSessionAndStart(url: url)
        }
    }

    private func activateSessionAndStart(url: URL) async {
        let session = AVAudioSession.sharedInstance()
        await MainActor.run { diag("activate session… url=\(url.lastPathComponent)") }
        do {
            let activated = try await session.activate(options: [])
            await MainActor.run { diag("activated=\(activated)") }
            if !activated {
                await MainActor.run {
                    errorMessage = "AudioSessionが許可されません。出力先を選び直してください。"
                    isPlaying = false
                    clearNowPlayingInfo()
                }
                return
            }
        } catch {
            await MainActor.run {
                errorMessage = "AudioSession activate失敗: \(error.localizedDescription)"
                diag("activate error: \(error.localizedDescription)")
                isPlaying = false
                clearNowPlayingInfo()
            }
            return
        }

        await MainActor.run {
            cleanupCurrentItem()
            let asset = AVURLAsset(url: url)
            let item = AVPlayerItem(asset: asset)

            // 既存playerを再利用 or 新規作成
            if let existing = player {
                existing.replaceCurrentItem(with: item)
            } else {
                player = AVPlayer(playerItem: item)
            }
            // バックグラウンド再生を継続させる重要設定
            player?.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
            currentItem = item

            // player.rate変化を観察
            rateObservation?.invalidate()
            rateObservation = player?.observe(\.rate, options: [.new, .old]) { [weak self] player, change in
                Task { @MainActor in
                    let new = change.newValue ?? 0
                    let old = change.oldValue ?? 0
                    self?.diag("rate \(old) → \(new)")
                }
            }

            // 再生終了を観察
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.next() }
            }

            // 再生エラーを観察
            statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
                Task { @MainActor in
                    if item.status == .failed {
                        self?.errorMessage = "再生失敗: \(item.error?.localizedDescription ?? "不明")"
                        self?.isPlaying = false
                    }
                }
            }

            player?.play()
            nowPlaying = url
            isPlaying = true
            updateNowPlayingInfo()
        }
    }

    private func cleanupCurrentItem() {
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
        statusObservation?.invalidate()
        statusObservation = nil
        rateObservation?.invalidate()
        rateObservation = nil
        currentItem = nil
    }

    func togglePlayPause() {
        guard let p = player else { return }
        if p.timeControlStatus == .playing {
            pause()
        } else {
            resume()
        }
    }

    func resume() {
        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }

    func stop() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        cleanupCurrentItem()
        player = nil
        nowPlaying = nil
        isPlaying = false
        queue = []
        currentIndex = 0
        contextLabel = ""
        clearNowPlayingInfo()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    func next() {
        guard !queue.isEmpty else { return }
        if currentIndex + 1 < queue.count {
            currentIndex += 1
            playCurrent()
        } else if loopEnabled {
            currentIndex = 0
            playCurrent()
        } else {
            stop()
        }
    }

    func previous() {
        guard !queue.isEmpty else { return }
        if currentIndex > 0 {
            currentIndex -= 1
            playCurrent()
        } else if loopEnabled {
            currentIndex = queue.count - 1
            playCurrent()
        }
    }

    private func updateNowPlayingInfo() {
        guard let url = nowPlaying else {
            clearNowPlayingInfo()
            return
        }
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = url.deletingPathExtension().lastPathComponent
        info[MPMediaItemPropertyArtist] = contextLabel.isEmpty ? "WatchPod" : contextLabel
        info[MPMediaItemPropertyAlbumTitle] = contextLabel.isEmpty ? "" : contextLabel
        if !queue.isEmpty {
            info[MPNowPlayingInfoPropertyPlaybackQueueIndex] = currentIndex
            info[MPNowPlayingInfoPropertyPlaybackQueueCount] = queue.count
        }
        if let item = currentItem {
            let duration = CMTimeGetSeconds(item.duration)
            if duration.isFinite && duration > 0 {
                info[MPMediaItemPropertyPlaybackDuration] = duration
            }
            let elapsed = CMTimeGetSeconds(item.currentTime())
            if elapsed.isFinite {
                info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
            }
        }
        let rate: Float = isPlaying ? 1.0 : 0.0
        info[MPNowPlayingInfoPropertyPlaybackRate] = rate
        info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }

    private func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }
}
