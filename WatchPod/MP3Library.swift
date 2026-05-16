import Foundation
import Combine

@MainActor
final class MP3Library: ObservableObject {
    @Published private(set) var items: [MP3Item] = []

    private let libraryDir: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Library", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    init() {
        reload()
    }

    func reload() {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: libraryDir,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        items = urls
            .filter { $0.pathExtension.lowercased() == "mp3" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { MP3Item(url: $0) }
    }

    /// Import a security-scoped URL (from file picker) into Documents/Library/.
    @discardableResult
    func importFile(from sourceURL: URL) throws -> URL {
        let didStart = sourceURL.startAccessingSecurityScopedResource()
        defer { if didStart { sourceURL.stopAccessingSecurityScopedResource() } }

        let destination = libraryDir.appendingPathComponent(sourceURL.lastPathComponent)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        reload()
        return destination
    }

    func remove(_ item: MP3Item) {
        try? FileManager.default.removeItem(at: item.url)
        reload()
    }
}
