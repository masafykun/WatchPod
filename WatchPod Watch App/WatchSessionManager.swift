import Foundation
import WatchConnectivity
import Combine

@MainActor
final class WatchSessionManager: NSObject, ObservableObject {
    @Published private(set) var tracks: [URL] = []
    @Published var lastReceived: String = ""

    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil

    let libraryDir: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Library", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    override init() {
        super.init()
        reloadTracks()
    }

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    func reloadTracks() {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: libraryDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        tracks = urls
            .filter { $0.pathExtension.lowercased() == "mp3" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        reloadTracks()
    }
}

extension WatchSessionManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {}

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let metadataName = (file.metadata?["name"] as? String) ?? file.fileURL.lastPathComponent
        let dest = libraryDir.appendingPathComponent(metadataName)
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.moveItem(at: file.fileURL, to: dest)
            Task { @MainActor in
                self.reloadTracks()
                self.lastReceived = metadataName
            }
        } catch {
            Task { @MainActor in
                self.lastReceived = "受信失敗: \(error.localizedDescription)"
            }
        }
    }
}
