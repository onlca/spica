import SwiftUI

struct PlayerDetailView: View {
    @ObservedObject var viewModel: PlayerViewModel
    
    var body: some View {
        Group {
            if let song = viewModel.currentSong {
                VStack(spacing: 24) {
                    // 专辑封面和元数据
                    AlbumArtView(song: song)
                    
                    // 播放控制
                    PlaybackControlsView(viewModel: viewModel)
                    
                    // 时间进度
                    ProgressView(value: viewModel.progress.isNaN ? 0 : viewModel.progress) {
                        let currentTime = viewModel.audioPlayer?.currentTime().seconds ?? 0
                        Text(timeString(time: currentTime))
                    } currentValueLabel: {
                        // 使用歌曲实际总时长，而不是计算值
                        Text(timeString(time: song.duration))
                    }
                    .padding(.horizontal)
                }
                .padding()
            } else {
                EmptyStateView()
            }
        }
        .frame(minWidth: 400, idealWidth: 600, maxWidth: .infinity)
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
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("选择左侧歌曲开始播放")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
    }
}
