import SwiftUI

struct LyricsDetailView: View {
    @ObservedObject var viewModel: PlayerViewModel
    
    var body: some View {
        ZStack {
            // 背景层，确保视图始终占据可用空间
            Color.clear
            
            if let song = viewModel.currentSong, !song.lyrics.isEmpty {
                LyricsView(lyrics: song.lyrics, viewModel: viewModel)
                    .padding()
                    .transition(.opacity)
            } else {
                Image(systemName: "text.quote")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary.opacity(0.3))
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
