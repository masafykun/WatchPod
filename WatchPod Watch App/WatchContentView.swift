import SwiftUI

struct WatchContentView: View {
    @EnvironmentObject var session: WatchSessionManager
    @EnvironmentObject var player: AudioPlayerManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                if let url = player.nowPlaying {
                    nowPlayingBar(url: url)
                }

                if session.tracks.isEmpty {
                    ContentUnavailableView(
                        "曲なし",
                        systemImage: "music.note",
                        description: Text("iPhoneアプリから\nWatchへ送信してください")
                    )
                } else {
                    List {
                        ForEach(session.tracks, id: \.self) { url in
                            Button {
                                player.play(url: url)
                            } label: {
                                HStack {
                                    Image(systemName: player.nowPlaying == url && player.isPlaying
                                          ? "speaker.wave.2.fill" : "music.note")
                                    Text(url.deletingPathExtension().lastPathComponent)
                                        .lineLimit(2)
                                }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    if player.nowPlaying == url { player.stop() }
                                    session.remove(url)
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("WatchPod")
            .alert("エラー",
                   isPresented: .constant(player.errorMessage != nil)) {
                Button("OK") { player.errorMessage = nil }
            } message: {
                Text(player.errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private func nowPlayingBar(url: URL) -> some View {
        HStack {
            Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .imageScale(.large)
                .onTapGesture { player.togglePlayPause() }
            VStack(alignment: .leading) {
                Text(url.deletingPathExtension().lastPathComponent)
                    .font(.caption)
                    .lineLimit(1)
                Text(player.isPlaying ? "再生中" : "停止")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                player.stop()
            } label: {
                Image(systemName: "stop.circle")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.gray.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    WatchContentView()
        .environmentObject(WatchSessionManager())
        .environmentObject(AudioPlayerManager())
}
