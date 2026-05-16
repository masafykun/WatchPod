import SwiftUI

@main
struct WatchPodWatchApp: App {
    @StateObject private var session = WatchSessionManager()
    @StateObject private var player = AudioPlayerManager()
    @StateObject private var weather = WeatherManager()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(session)
                .environmentObject(player)
                .environmentObject(weather)
                .onAppear {
                    session.activate()
                    player.configureAudioSession()
                    weather.start()
                }
        }
    }
}

enum WatchPage: Hashable {
    case weather, clock, songs, playlists
}

struct WatchRootView: View {
    @State private var selectedPage: WatchPage = .clock

    var body: some View {
        TabView(selection: $selectedPage) {
            WeatherView()
                .tag(WatchPage.weather)

            ClockView()
                .tag(WatchPage.clock)

            WatchContentView()
                .tag(WatchPage.songs)

            WatchPlaylistsView()
                .tag(WatchPage.playlists)
        }
        .tabViewStyle(.page)
    }
}
