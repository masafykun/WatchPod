import SwiftUI

struct WatchPlaylistsView: View {
    @EnvironmentObject var session: WatchSessionManager
    @EnvironmentObject var player: AudioPlayerManager

    var body: some View {
        NavigationStack {
            List {
                if session.playlists.isEmpty {
                    Section {
                        VStack(spacing: 6) {
                            Image(systemName: "music.note.list")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("プレイリストなし").font(.headline)
                            Text("iPhone側で作成し\n「Watch同期」してください")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                    }
                } else {
                    ForEach(session.playlists) { pl in
                        NavigationLink {
                            WatchPlaylistDetailView(playlist: pl)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(pl.name).font(.body).lineLimit(1)
                                Text("\(pl.trackFileNames.count)曲")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("プレイリスト")
        }
    }
}

struct WatchPlaylistDetailView: View {
    let playlist: Playlist
    @EnvironmentObject var session: WatchSessionManager
    @EnvironmentObject var player: AudioPlayerManager

    private var availableURLs: [(name: String, url: URL?)] {
        playlist.trackFileNames.map { name in
            let url = session.tracks.first { $0.lastPathComponent == name }
            return (name, url)
        }
    }

    private var resolvedURLs: [URL] {
        availableURLs.compactMap { $0.url }
    }

    var body: some View {
        List {
            Section {
                Button {
                    let urls = resolvedURLs
                    guard !urls.isEmpty else { return }
                    player.playPlaylist(urls: urls, startAt: 0, label: playlist.name)
                } label: {
                    Label("最初から再生", systemImage: "play.fill")
                }
                .disabled(resolvedURLs.isEmpty)

                Toggle(isOn: $player.loopEnabled) {
                    Label("ループ再生", systemImage: "repeat")
                }
            }

            Section("曲") {
                ForEach(Array(availableURLs.enumerated()), id: \.offset) { idx, item in
                    Button {
                        guard item.url != nil else { return }
                        player.playPlaylist(urls: resolvedURLs, startAt: idx, label: playlist.name)
                    } label: {
                        HStack {
                            Image(systemName: item.url == nil ? "exclamationmark.triangle"
                                  : (player.nowPlaying == item.url && player.isPlaying
                                     ? "speaker.wave.2.fill" : "music.note"))
                            VStack(alignment: .leading) {
                                Text(item.name).lineLimit(1)
                                if item.url == nil {
                                    Text("未送信")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                    .disabled(item.url == nil)
                }
            }
        }
        .navigationTitle(playlist.name)
    }
}
