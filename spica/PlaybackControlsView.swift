import SwiftUI

struct PlaybackControlsView: View {
    @ObservedObject var viewModel: PlayerViewModel
    
    var body: some View {
        HStack(spacing: 32) {
            Button(action: playPrevious) {
                Image(systemName: "backward.fill")
                    .font(.title)
            }
            
            Button(action: togglePlayback) {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 48))
            }
            
            Button(action: playNext) {
                Image(systemName: "forward.fill")
                    .font(.title)
            }
        }
        .buttonStyle(.plain)
        .foregroundColor(.primary)
    }
    
    private func togglePlayback() {
        if viewModel.isPlaying {
            viewModel.pause()
        } else if let currentSong = viewModel.currentSong {
            viewModel.play(song: currentSong)
        }
    }
    
    private func playPrevious() {
        guard !viewModel.playlist.isEmpty,
              let currentSong = viewModel.currentSong,
              let currentIndex = viewModel.playlist.firstIndex(where: { $0.id == currentSong.id }) else { return }
        
        let previousIndex = (currentIndex - 1 + viewModel.playlist.count) % viewModel.playlist.count
        viewModel.play(song: viewModel.playlist[previousIndex])
    }
    
    private func playNext() {
        guard !viewModel.playlist.isEmpty,
              let currentSong = viewModel.currentSong, 
              let currentIndex = viewModel.playlist.firstIndex(where: { $0.id == currentSong.id }) else { return }
        
        let nextIndex = (currentIndex + 1) % viewModel.playlist.count
        viewModel.play(song: viewModel.playlist[nextIndex])
    }
}
