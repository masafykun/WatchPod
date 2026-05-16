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
