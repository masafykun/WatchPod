import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var library: MP3Library
    @EnvironmentObject var session: PhoneSessionManager
    @State private var isImporterPresented = false
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                statusBar
                List {
                    if library.items.isEmpty {
                        ContentUnavailableView(
                            "MP3がありません",
                            systemImage: "music.note",
                            description: Text("右上の＋からMP3を取り込み、Watchへ送信します。")
                        )
                    } else {
                        ForEach(library.items) { item in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.displayName).font(.body)
                                    Text(byteString(item.fileSize)).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Menu {
                                    Button {
                                        session.sendFile(item.url)
                                    } label: {
                                        Label("Watchへ送信", systemImage: "arrow.up.to.line")
                                    }
                                    Button(role: .destructive) {
                                        session.requestDeleteFromWatch(fileName: item.url.lastPathComponent)
                                    } label: {
                                        Label("Watchから削除", systemImage: "applewatch.slash")
                                    }
                                } label: {
                                    Image(systemName: "applewatch")
                                        .padding(8)
                                }
                                .menuStyle(.borderlessButton)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    library.remove(item)
                                } label: {
                                    Label("ローカル削除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("WatchPod")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isImporterPresented = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [.mp3, .audio],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    for url in urls {
                        do {
                            try library.importFile(from: url)
                        } catch {
                            importError = error.localizedDescription
                        }
                    }
                case .failure(let error):
                    importError = error.localizedDescription
                }
            }
            .alert("取り込みエラー", isPresented: .constant(importError != nil)) {
                Button("OK") { importError = nil }
            } message: {
                Text(importError ?? "")
            }
        }
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            Label(session.isWatchAppInstalled ? "Watch検出" : "Watch未検出",
                  systemImage: "applewatch")
                .foregroundStyle(session.isWatchAppInstalled ? .green : .secondary)
            Spacer()
            if !session.lastTransferStatus.isEmpty {
                Text(session.lastTransferStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .font(.caption)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func byteString(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

#Preview {
    ContentView()
        .environmentObject(MP3Library())
        .environmentObject(PhoneSessionManager())
}
