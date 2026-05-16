import SwiftUI

struct PlaylistDetailView: View {
    let playlistID: Playlist.ID
    @EnvironmentObject var library: MP3Library
    @EnvironmentObject var session: PhoneSessionManager
    @EnvironmentObject var store: PlaylistStore
    @State private var renaming = false
    @State private var newName = ""
    @State private var pickerOpen = false

    private var playlist: Playlist? {
        store.playlists.first(where: { $0.id == playlistID })
    }

    var body: some View {
        let playlist = self.playlist ?? Playlist(name: "?")

        List {
            Section("曲 (\(playlist.trackFileNames.count))") {
                if playlist.trackFileNames.isEmpty {
                    Text("曲なし。下の「曲を追加」から選んでください。")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(playlist.trackFileNames, id: \.self) { name in
                        HStack {
                            Image(systemName: "music.note")
                            Text(name).lineLimit(1)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                store.removeTrack(name, from: playlistID)
                                session.syncPlaylists(store.playlists)
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                    .onMove { from, to in
                        guard var pl = self.playlist else { return }
                        pl.trackFileNames.move(fromOffsets: from, toOffset: to)
                        store.update(pl)
                        session.syncPlaylists(store.playlists)
                    }
                }
            }

            Section {
                Button {
                    pickerOpen = true
                } label: {
                    Label("曲を追加", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle(playlist.name)
        .toolbar {
            EditButton()
            Menu {
                Button("プレイリスト名を変更") {
                    newName = playlist.name
                    renaming = true
                }
                Button("Watch同期", systemImage: "applewatch.radiowaves.left.and.right") {
                    session.syncPlaylists(store.playlists)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .alert("プレイリスト名を変更", isPresented: $renaming) {
            TextField("名前", text: $newName)
            Button("キャンセル", role: .cancel) {}
            Button("OK") {
                guard var pl = self.playlist else { return }
                let trimmed = newName.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                pl.name = trimmed
                store.update(pl)
                session.syncPlaylists(store.playlists)
            }
        }
        .sheet(isPresented: $pickerOpen) {
            NavigationStack {
                TrackPickerView(excludeFileNames: Set(playlist.trackFileNames)) { selected in
                    for name in selected {
                        store.addTrack(name, to: playlistID)
                    }
                    session.syncPlaylists(store.playlists)
                    pickerOpen = false
                }
            }
        }
    }
}

struct TrackPickerView: View {
    let excludeFileNames: Set<String>
    let onConfirm: (Set<String>) -> Void

    @EnvironmentObject var library: MP3Library
    @State private var selection: Set<String> = []

    var candidates: [MP3Item] {
        library.items.filter { !excludeFileNames.contains($0.url.lastPathComponent) }
    }

    var body: some View {
        List {
            if candidates.isEmpty {
                Text("追加できる曲なし。先に「曲」タブからMP3を取り込んでください。")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(candidates) { item in
                    HStack {
                        Image(systemName: selection.contains(item.url.lastPathComponent)
                              ? "checkmark.circle.fill" : "circle")
                        Text(item.displayName).lineLimit(1)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        let name = item.url.lastPathComponent
                        if selection.contains(name) {
                            selection.remove(name)
                        } else {
                            selection.insert(name)
                        }
                    }
                }
            }
        }
        .navigationTitle("曲を追加")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { onConfirm([]) }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("追加 (\(selection.count))") {
                    onConfirm(selection)
                }
                .disabled(selection.isEmpty)
            }
        }
    }
}
