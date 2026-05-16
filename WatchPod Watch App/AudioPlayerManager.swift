import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioPlayerManager: NSObject, ObservableObject {
    @Published private(set) var nowPlaying: URL?
    @Published private(set) var isPlaying: Bool = false
    @Published var errorMessage: String?

    private var player: AVAudioPlayer?

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
    }

    func play(url: URL) {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(true, options: [])
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.prepareToPlay()
            p.play()
            player = p
            nowPlaying = url
            isPlaying = true
        } catch {
            errorMessage = "再生失敗: \(error.localizedDescription)"
            isPlaying = false
        }
    }

    func togglePlayPause() {
        guard let p = player else { return }
        if p.isPlaying {
            p.pause()
            isPlaying = false
        } else {
            p.play()
            isPlaying = true
        }
    }

    func stop() {
        player?.stop()
        player = nil
        nowPlaying = nil
        isPlaying = false
    }
}

extension AudioPlayerManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.nowPlaying = nil
        }
    }
}
