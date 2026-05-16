import SwiftUI

@main
struct WatchPodWatchApp: App {
    @StateObject private var session = WatchSessionManager()
    @StateObject private var player = AudioPlayerManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(session)
                .environmentObject(player)
                .onAppear {
                    session.activate()
                    player.configureAudioSession()
                }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active: player.recordScenePhase("active")
            case .inactive: player.recordScenePhase("inactive")
            case .background: player.recordScenePhase("background")
            @unknown default: player.recordScenePhase("unknown")
            }
        }
    }
}

struct WatchRootView: View {
    var body: some View {
        TabView {
            WatchContentView()
            WatchPlaylistsView()
        }
        .tabViewStyle(.page)
    }
}
