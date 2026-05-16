import SwiftUI

struct PlaylistListView: View {
    @EnvironmentObject var library: MP3Library
    @EnvironmentObject var session: PhoneSessionManager
    @EnvironmentObject var store: PlaylistStore
    @State private var showingNewSheet = false
    @State private var newName: String = ""

    var body: some View {
        NavigationStack {
            List {
                if store.playlists.isEmpty {
                    ContentUnavailableView(
                        "プレイリストなし",
                        systemImage: "music.note.list",
                        description: Text("右上の＋から作成し、曲を追加してWatchに同期します。")
                    )
                } else {
                    ForEach(store.playlists) { playlist in
                        NavigationLink {
                            PlaylistDetailView(playlistID: playlist.id)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(playlist.name).font(.body)
                                Text("\(playlist.trackFileNames.count)曲")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                store.delete(playlist)
                                session.syncPlaylists(store.playlists)
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("プレイリスト")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newName = ""
                        showingNewSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        session.syncPlaylists(store.playlists)
                    } label: {
                        Label("Watch同期", systemImage: "applewatch.radiowaves.left.and.right")
                    }
                    .disabled(!session.isWatchAppInstalled)
                }
            }
            .sheet(isPresented: $showingNewSheet) {
                NavigationStack {
                    Form {
                        TextField("プレイリスト名", text: $newName)
                    }
                    .navigationTitle("新規プレイリスト")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("キャンセル") { showingNewSheet = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("作成") {
                                let trimmed = newName.trimmingCharacters(in: .whitespaces)
                                guard !trimmed.isEmpty else { return }
                                _ = store.create(name: trimmed)
                                session.syncPlaylists(store.playlists)
                                showingNewSheet = false
                            }
                            .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }
}
