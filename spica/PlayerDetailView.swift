import SwiftUI

struct PlayerDetailView: View {
    @ObservedObject var viewModel: PlayerViewModel
    
    var body: some View {
        Group {
            if let song = viewModel.currentSong {
                VStack(spacing: 20) {
                    // 专辑封面和元数据
                    AlbumArtView(song: song)
                    
                    // 播放控制
                    PlaybackControlsView(viewModel: viewModel)
                    
                    // 时间进度和拖动条
                    VStack(spacing: 8) {
                        Slider(
                            value: Binding(
                                get: { viewModel.progress.isNaN ? 0 : viewModel.progress },
                                set: { newValue in
                                    viewModel.seek(to: newValue)
                                }
                            ),
                            in: 0...1
                        )
                        .controlSize(.regular)
                        
                        HStack {
                            let currentTime = viewModel.audioPlayer?.currentTime().seconds ?? 0
                            Text(timeString(time: currentTime))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                            
                            Spacer()
                            
                            Text(timeString(time: song.duration))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .padding(.horizontal)
                }
                .padding()
            } else {
                EmptyStateView()
            }
        }
        .frame(minWidth: 300, idealWidth: 400, maxWidth: .infinity)
    }
    
    private func timeString(time: Double) -> String {
        if time.isNaN || time.isInfinite || time < 0 {
            return "00:00"
        }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct EmptyStateView: View {
    var body: some View {
        Image(systemName: "music.note.list")
            .font(.system(size: 64))
            .foregroundColor(.secondary.opacity(0.3))
            .frame(maxHeight: .infinity)
    }
}
