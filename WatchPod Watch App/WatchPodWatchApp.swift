import SwiftUI

@main
struct WatchPodWatchApp: App {
    @StateObject private var session = WatchSessionManager()
    @StateObject private var player = AudioPlayerManager()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(session)
                .environmentObject(player)
                .onAppear {
                    session.activate()
                    player.configureAudioSession()
                }
        }
    }
}
