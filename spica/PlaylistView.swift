import SwiftUI

struct PlaylistView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @ObservedObject private var settings = SettingsModel.shared
    @Binding var showFileImporter: Bool
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            // 动态决定显示的列
            let showArtist = settings.showPlaylistArtist && width > 450
            let showAlbum = settings.showPlaylistAlbum && width > 600
            let showDuration = settings.showPlaylistDuration && width > 350
            
            VStack(spacing: 0) {
                // 表头
                HStack(spacing: 10) {
                    // 序号列
                    Text("#")
                        .frame(width: 30, alignment: .center)
                        .foregroundColor(.secondary)
                    
                    // 标题列
                    Text("标题")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 艺术家列
                    if showArtist {
                        Text("艺术家")
                            .frame(width: 120, alignment: .leading)
                    }
                    
                    // 专辑列
                    if showAlbum {
                        Text("专辑")
                            .frame(width: 120, alignment: .leading)
                    }
                    
                    // 时长列
                    if showDuration {
                        Text("时长")
                            .frame(width: 60, alignment: .trailing)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.controlBackgroundColor))
                
                Divider()
                
                // 列表内容
                List {
                    ForEach(Array(viewModel.filteredPlaylist.enumerated()), id: \.element.id) { index, song in
                        Button(action: { viewModel.play(song: song) }) {
                            HStack(spacing: 10) {
                                // 序号/播放状态
                                Group {
                                    if viewModel.currentSong?.id == song.id {
                                        Image(systemName: "speaker.wave.3.fill")
                                            .foregroundColor(.accentColor)
                                    } else {
                                        Text("\(index + 1)")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .frame(width: 30, alignment: .center)
                                
                                // 标题
                                Text(song.title)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundColor(viewModel.currentSong?.id == song.id ? .accentColor : .primary)
                                
                                // 艺术家
                                if showArtist {
                                    Text(song.artist)
                                        .lineLimit(1)
                                        .frame(width: 120, alignment: .leading)
                                        .foregroundColor(.secondary)
                                }
                                
                                // 专辑
                                if showAlbum {
                                    Text(song.album)
                                        .lineLimit(1)
                                        .frame(width: 120, alignment: .leading)
                                        .foregroundColor(.secondary)
                                }
                                
                                // 时长
                                if showDuration {
                                    Text(formatDuration(song.duration))
                                        .lineLimit(1)
                                        .frame(width: 60, alignment: .trailing)
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                }
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                viewModel.removeSongFromPlaylist(song)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                    .onMove(perform: viewModel.moveSong)
                }
                .listStyle(.plain)
            }
            .searchable(text: $viewModel.searchText, prompt: "搜索音乐库")
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
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
