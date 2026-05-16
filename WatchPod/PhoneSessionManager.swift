import Foundation
import WatchConnectivity
import Combine

@MainActor
final class PhoneSessionManager: NSObject, ObservableObject {
    @Published var isReachable: Bool = false
    @Published var isWatchAppInstalled: Bool = false
    @Published var lastTransferStatus: String = ""
    @Published var pendingTransfers: [String] = []

    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    func sendFile(_ url: URL) {
        guard let session else {
            lastTransferStatus = "WCSession unsupported"
            return
        }
        guard session.activationState == .activated else {
            lastTransferStatus = "Session not active"
            return
        }
        let transfer = session.transferFile(url, metadata: ["name": url.lastPathComponent])
        pendingTransfers.append(transfer.file.fileURL.lastPathComponent)
        lastTransferStatus = "Sending \(url.lastPathComponent)…"
    }

    /// Watch側にファイル削除リクエストを送る
    func requestDeleteFromWatch(fileName: String) {
        guard let session, session.activationState == .activated else {
            lastTransferStatus = "Session not active"
            return
        }
        guard session.isReachable else {
            lastTransferStatus = "Watch unreachable (アプリ起動中か確認)"
            return
        }
        lastTransferStatus = "Watchから削除中: \(fileName)…"
        session.sendMessage(
            ["action": "delete", "name": fileName],
            replyHandler: { reply in
                Task { @MainActor in
                    if let status = reply["status"] as? String, status == "deleted" {
                        self.lastTransferStatus = "Watch削除完了: \(fileName) ✓"
                    } else if let status = reply["status"] as? String, status == "not_found" {
                        self.lastTransferStatus = "Watchに無し: \(fileName)"
                    } else {
                        self.lastTransferStatus = "Watch返信: \(reply)"
                    }
                }
            },
            errorHandler: { error in
                Task { @MainActor in
                    self.lastTransferStatus = "削除失敗: \(error.localizedDescription)"
                }
            }
        )
    }

    /// Watch側にプレイリスト一覧を送信（applicationContext経由）
    func syncPlaylists(_ playlists: [Playlist]) {
        guard let session, session.activationState == .activated else { return }
        do {
            let data = try JSONEncoder().encode(playlists)
            try session.updateApplicationContext([
                "playlists": data
            ])
            lastTransferStatus = "プレイリスト同期 (\(playlists.count)件)"
        } catch {
            lastTransferStatus = "同期失敗: \(error.localizedDescription)"
        }
    }

    private func refreshState() {
        guard let session else { return }
        isReachable = session.isReachable
        isWatchAppInstalled = session.isWatchAppInstalled
    }
}

extension PhoneSessionManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        Task { @MainActor in self.refreshState() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.refreshState() }
    }

    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        let name = fileTransfer.file.fileURL.lastPathComponent
        Task { @MainActor in
            self.pendingTransfers.removeAll { $0 == name }
            if let error {
                self.lastTransferStatus = "Failed \(name): \(error.localizedDescription)"
            } else {
                self.lastTransferStatus = "Sent \(name) ✓"
            }
        }
    }
}
