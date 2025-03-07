import SwiftUI
import AVKit
import Combine

// 安全访问文件模型
struct SecureSong: Identifiable {
    let id = UUID()
    let title: String
    let artist: String
    let duration: Double
    let fileURL: URL
    var lyrics: [String] = []
    var securityScoped: Bool = false
}

class PlayerViewModel: NSObject, ObservableObject {
    @Published var currentSong: SecureSong?
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var playlist: [SecureSong] = []
    @Published var errorMessage: String?
    
    public var audioPlayer: AVPlayer?
    private var timeObserver: Any?
    private var securityScopedURLs = [URL]()
    
    // 安全添加歌曲
    func addSongs(_ urls: [URL]) {
        urls.forEach { url in
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "文件访问被拒绝: \(url.lastPathComponent)"
                return
            }
            
            securityScopedURLs.append(url)
            
            let asset = AVAsset(url: url)
            let duration = CMTimeGetSeconds(asset.duration)
            
            let newSong = SecureSong(
                title: url.deletingPathExtension().lastPathComponent,
                artist: asset.metadata.first(where: { $0.commonKey == .commonKeyArtist })?.stringValue ?? "未知艺术家",
                duration: duration.isNaN ? 0 : duration,
                fileURL: url,
                securityScoped: true
            )
            
            playlist.append(newSong)
        }
    }
    
    // 安全播放控制
    func play(song: SecureSong) {
        guard song.fileURL.startAccessingSecurityScopedResource() else {
            errorMessage = "播放权限获取失败"
            return
        }
        
        if currentSong?.id != song.id {
            audioPlayer?.pause()
            audioPlayer = AVPlayer(url: song.fileURL)
            setupPlayerObservers()
        }
        
        currentSong = song
        audioPlayer?.play()
        isPlaying = true
    }
    
    private func setupPlayerObservers() {
        timeObserver = audioPlayer?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self, let duration = self.audioPlayer?.currentItem?.duration else { return }
            self.progress = time.seconds / duration.seconds
        }
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
    }
    
    func stop() {
        audioPlayer?.pause()
        audioPlayer?.seek(to: .zero)
        isPlaying = false
        progress = 0
    }
    
    // 释放资源
    func releaseSecurityScopedResources() {
        securityScopedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
        securityScopedURLs.removeAll()
    }
    
    deinit {
        if let observer = timeObserver {
            audioPlayer?.removeTimeObserver(observer)
        }
        releaseSecurityScopedResources()
    }
}

struct ContentView: View {
    @StateObject private var viewModel = PlayerViewModel()
    @State private var showFileImporter = false
    
    var body: some View {
        NavigationSplitView {
            PlaylistView(viewModel: viewModel, showFileImporter: $showFileImporter)
        } detail: {
            PlayerDetailView(viewModel: viewModel)
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

// 播放列表视图
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
                }
                .contextMenu {
                    Button(role: .destructive) {
                        removeSong(song)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
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
        if let index = viewModel.playlist.firstIndex(where: { $0.id == song.id }) {
            song.fileURL.stopAccessingSecurityScopedResource()
            viewModel.playlist.remove(at: index)
            if viewModel.currentSong?.id == song.id {
                viewModel.stop()
            }
        }
    }
}

// 播放器详情视图
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
                        let duration = song.duration * (viewModel.progress.isNaN ? 0 : viewModel.progress)
                        Text(timeString(time: duration))
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
        if time.isNaN {
            return "00:00"
        }
        if time.isInfinite {
            return "00:00"
        }
        if time < 0 {
            return "00:00"
        }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// 组件分解
struct AlbumArtView: View {
    let song: SecureSong
    
    var body: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(.thinMaterial)
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                )
            
            VStack {
                Text(song.title)
                    .font(.title2.bold())
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

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

#Preview {
    ContentView()
}
