import SwiftUI

struct PlaylistView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @Binding var showFileImporter: Bool
    @State private var showSortOptions = false
    
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
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        removeSong(song)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("播放列表")
        .toolbar {
            // 排序按钮
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        viewModel.sortPlaylist(by: .title)
                    } label: {
                        Label("按标题排序", systemImage: "textformat.abc")
                    }
                    
                    Button {
                        viewModel.sortPlaylist(by: .artist)
                    } label: {
                        Label("按艺术家排序", systemImage: "music.mic")
                    }
                    
                    Button {
                        viewModel.sortPlaylist(by: .album)
                    } label: {
                        Label("按专辑排序", systemImage: "square.stack")
                    }
                    
                    Button {
                        viewModel.sortPlaylist(by: .random)
                    } label: {
                        Label("随机排序", systemImage: "shuffle")
                    }
                } label: {
                    Label("排序", systemImage: "arrow.up.arrow.down")
                }
                .disabled(viewModel.playlist.isEmpty)
            }
            
            // 添加歌曲按钮
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
