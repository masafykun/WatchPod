import Foundation
import WatchConnectivity
import Combine

@MainActor
final class WatchSessionManager: NSObject, ObservableObject {
    @Published private(set) var tracks: [URL] = []
    @Published private(set) var playlists: [Playlist] = []
    @Published var lastReceived: String = ""

    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil

    let libraryDir: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Library", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private let playlistsFile: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("playlists.json")
    }()

    override init() {
        super.init()
        reloadTracks()
        loadPlaylistsFromDisk()
    }

    private func loadPlaylistsFromDisk() {
        guard let data = try? Data(contentsOf: playlistsFile),
              let decoded = try? JSONDecoder().decode([Playlist].self, from: data) else { return }
        playlists = decoded
    }

    private func savePlaylistsToDisk() {
        guard let data = try? JSONEncoder().encode(playlists) else { return }
        try? data.write(to: playlistsFile)
    }

    fileprivate func updatePlaylists(_ newPlaylists: [Playlist]) {
        playlists = newPlaylists
        savePlaylistsToDisk()
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
                             error: Error?) {
        let context = session.receivedApplicationContext
        Task { @MainActor in
            self.handleApplicationContext(context)
        }
    }

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

    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        if let action = message["action"] as? String, action == "delete",
           let name = message["name"] as? String {
            let target = libraryDir.appendingPathComponent(name)
            let exists = FileManager.default.fileExists(atPath: target.path)
            if exists {
                try? FileManager.default.removeItem(at: target)
                Task { @MainActor in
                    self.reloadTracks()
                    self.lastReceived = "削除: \(name)"
                }
                replyHandler(["status": "deleted", "name": name])
            } else {
                replyHandler(["status": "not_found", "name": name])
            }
        } else {
            replyHandler(["status": "unknown_action"])
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            self.handleApplicationContext(applicationContext)
        }
    }

    @MainActor
    private func handleApplicationContext(_ context: [String: Any]) {
        if let data = context["playlists"] as? Data,
           let decoded = try? JSONDecoder().decode([Playlist].self, from: data) {
            updatePlaylists(decoded)
        }
    }
}
