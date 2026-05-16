import Foundation

struct Playlist: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var name: String
    var trackFileNames: [String]
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, trackFileNames: [String] = [], createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.trackFileNames = trackFileNames
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
