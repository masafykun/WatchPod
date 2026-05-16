import SwiftUI

@main
struct WatchPodApp: App {
    @StateObject private var library = MP3Library()
    @StateObject private var session = PhoneSessionManager()
    @StateObject private var store = PlaylistStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(library)
                .environmentObject(session)
                .environmentObject(store)
                .onAppear {
                    session.activate()
                }
        }
    }
}

struct RootTabView: View {
    @EnvironmentObject var session: PhoneSessionManager
    @EnvironmentObject var store: PlaylistStore

    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("曲", systemImage: "music.note")
                }

            PlaylistListView()
                .tabItem {
                    Label("プレイリスト", systemImage: "music.note.list")
                }
        }
        .onChange(of: session.isWatchAppInstalled) { _, installed in
            if installed { session.syncPlaylists(store.playlists) }
        }
    }
}
