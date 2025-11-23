import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PlayerViewModel()
    @State private var showFileImporter = false
    @State private var showingSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                // 第一栏：播放列表
                PlaylistView(viewModel: viewModel, showFileImporter: $showFileImporter)
            } content: {
                // 第二栏：播放器控制
                PlayerDetailView(viewModel: viewModel)
                    .navigationTitle("spica")

            } detail: {
                // 第三栏：歌词视图
                LyricsDetailView(viewModel: viewModel)
                    .navigationTitle("歌词")
            }
            
            // 底部状态栏
            AudioInfoStatusBar(viewModel: viewModel)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result: result)
        }
        .alert("发生错误", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("确定", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .toolbar {            
            // 设置按钮
            ToolbarItem() {
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gear")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
    
    private func handleFileImport(result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            viewModel.addSongs(urls)
        } catch {
            viewModel.errorMessage = "文件导入失败: \(error.localizedDescription)"
        }
    }
}

// 底部状态栏视图
struct AudioInfoStatusBar: View {
    @ObservedObject var viewModel: PlayerViewModel
    
    var body: some View {
        if viewModel.currentSong != nil {
            HStack {
                Divider()
                    .frame(height: 15)
                
                // 文件格式
                Text(viewModel.audioInfo.fileFormat)
                    .font(.system(size: 12))
                
                Divider()
                    .frame(height: 15)
                
                // 比特率
                Text("\(viewModel.audioInfo.bitrate) kbps")
                    .font(.system(size: 12))
                
                Divider()
                    .frame(height: 15)
                
                // 采样率
                Text(String(format: "%.1f kHz", viewModel.audioInfo.sampleRate / 1000))
                    .font(.system(size: 12))
                
                Divider()
                    .frame(height: 15)
                
                // 声道信息
                Text("\(viewModel.audioInfo.channels)声道")
                    .font(.system(size: 12))
                
                Divider()
                    .frame(height: 15)
                
                // 文件大小
                Text(viewModel.audioInfo.formattedFileSize)
                    .font(.system(size: 12))
                
                Spacer()
            }
            .padding(.horizontal)
            .frame(height: 24)
            .background(.ultraThinMaterial)
        } else {
            EmptyView()
        }
    }
}
