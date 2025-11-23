import SwiftUI

struct LyricsDetailView: View {
    @ObservedObject var viewModel: PlayerViewModel
    
    var body: some View {
        Group {
            if let song = viewModel.currentSong {
                if !song.lyrics.isEmpty {
                    LyricsView(lyrics: song.lyrics, viewModel: viewModel)
                        .padding()
                } else {
                    Image(systemName: "text.quote")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary.opacity(0.3))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                Image(systemName: "text.quote")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary.opacity(0.3))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
