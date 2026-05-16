import SwiftUI

struct DiagnosticView: View {
    @EnvironmentObject var player: AudioPlayerManager

    var body: some View {
        ScrollView {
            Text(player.diagnosticLog.isEmpty ? "(no events)" : player.diagnosticLog)
                .font(.system(size: 10, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
        }
        .navigationTitle("Diag")
    }
}
