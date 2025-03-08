import SwiftUI

struct PlaylistView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @Binding var showFileImporter: Bool
    
    var body: some View {
        List {
            ForEach(viewModel.playlist) { song in
                Button(action: { viewModel.play(song: song) }) {
                    HStack {
                        Text(song.title)
                            .lineLimit(1)
                        Spacer()
                        if viewModel.currentSong?.id == song.id {
                            Image(systemName: "speaker.wave.3")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)  // 使用plain样式移除边框和背景色
                .contextMenu {
                    Button(role: .destructive) {
                        removeSong(song)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.sidebar)  // 使用sidebar样式更贴合macOS侧栏设计
        .navigationTitle("播放列表")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showFileImporter.toggle() }) {
                    Label("添加歌曲", systemImage: "plus")
                }
            }
        }
    }
    
    private func removeSong(_ song: SecureSong) {
        viewModel.removeSongFromPlaylist(song)
    }
}
