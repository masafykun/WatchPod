import Foundation
import Combine

@MainActor
final class PlaylistStore: ObservableObject {
    @Published var playlists: [Playlist] = [] {
        didSet { save() }
    }

    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("playlists.json")
    }()

    init() {
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Playlist].self, from: data) else { return }
        playlists = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(playlists) else { return }
        try? data.write(to: fileURL)
    }

    func create(name: String) -> Playlist {
        let new = Playlist(name: name)
        playlists.append(new)
        return new
    }

    func update(_ playlist: Playlist) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        var updated = playlist
        updated.updatedAt = Date()
        playlists[idx] = updated
    }

    func delete(_ playlist: Playlist) {
        playlists.removeAll { $0.id == playlist.id }
    }

    func addTrack(_ fileName: String, to playlistID: Playlist.ID) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        if !playlists[idx].trackFileNames.contains(fileName) {
            playlists[idx].trackFileNames.append(fileName)
            playlists[idx].updatedAt = Date()
        }
    }

    func removeTrack(_ fileName: String, from playlistID: Playlist.ID) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        playlists[idx].trackFileNames.removeAll { $0 == fileName }
        playlists[idx].updatedAt = Date()
    }
}
