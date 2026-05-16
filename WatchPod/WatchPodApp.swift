import SwiftUI

@main
struct WatchPodApp: App {
    @StateObject private var library = MP3Library()
    @StateObject private var session = PhoneSessionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
                .environmentObject(session)
                .onAppear {
                    session.activate()
                }
        }
    }
}
