import Foundation

struct MP3Item: Identifiable, Equatable, Hashable {
    let id = UUID()
    let url: URL
    var displayName: String { url.deletingPathExtension().lastPathComponent }
    var fileSize: Int64 {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
    }
}
