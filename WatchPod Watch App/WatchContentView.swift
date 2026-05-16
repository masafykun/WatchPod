import SwiftUI

struct WatchContentView: View {
    @EnvironmentObject var session: WatchSessionManager
    @EnvironmentObject var player: AudioPlayerManager

    var body: some View {
        NavigationStack {
            List {
                if let url = player.nowPlaying {
                    Section {
                        nowPlayingBar(url: url)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }

                Section {
                    Button {
                        Task { await player.presentOutputPicker() }
                    } label: {
                        HStack {
                            Image(systemName: outputIcon)
                            VStack(alignment: .leading) {
                                Text("出力先")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(player.currentOutputName)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                        }
                    }
                    NavigationLink {
                        DiagnosticView()
                    } label: {
                        Label("診断ログ", systemImage: "ladybug")
                            .font(.caption)
                    }
                }

                if session.tracks.isEmpty {
                    Section {
                        VStack(spacing: 6) {
                            Image(systemName: "music.note")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("曲なし").font(.headline)
                            Text("iPhoneアプリから\nWatchへ送信してください")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Section("曲") {
                        ForEach(session.tracks, id: \.self) { url in
                            trackRow(url: url)
                        }
                    }
                }
            }
            .listStyle(.carousel)
            .navigationTitle("WatchPod")
            .alert("エラー",
                   isPresented: .constant(player.errorMessage != nil)) {
                Button("OK") { player.errorMessage = nil }
            } message: {
                Text(player.errorMessage ?? "")
            }
        }
    }

    private var outputIcon: String {
        let name = player.currentOutputName.lowercased()
        if name.contains("airpod") { return "airpods" }
        if name.contains("speaker") || name.contains("watch") { return "applewatch" }
        if name.contains("bluetooth") || name.contains("headphone") { return "headphones" }
        return "speaker.wave.2"
    }

    @ViewBuilder
    private func trackRow(url: URL) -> some View {
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

    @ViewBuilder
    private func nowPlayingBar(url: URL) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(url.deletingPathExtension().lastPathComponent)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
            HStack(spacing: 12) {
                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .imageScale(.large)
                }
                .buttonStyle(.plain)

                Text(player.isPlaying ? "再生中" : "停止")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    player.stop()
                } label: {
                    Image(systemName: "stop.circle")
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(.gray.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    WatchContentView()
        .environmentObject(WatchSessionManager())
        .environmentObject(AudioPlayerManager())
}
