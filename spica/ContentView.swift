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
    private var playerItemObservation: NSKeyValueObservation?
    
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
        // 如果是继续播放同一首歌曲
        if let currentSong = currentSong, currentSong.id == song.id {
            audioPlayer?.play()
            isPlaying = true
            return
        }
        
        // 停止当前播放并清理
        cleanupCurrentPlayback()
        
        guard song.fileURL.startAccessingSecurityScopedResource() else {
            errorMessage = "播放权限获取失败"
            return
        }
        
        // 创建新的播放项
        let playerItem = AVPlayerItem(url: song.fileURL)
        audioPlayer = AVPlayer(playerItem: playerItem)
        
        // 设置观察者
        setupPlayerObservers()
        
        // 添加播放结束通知观察
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        
        currentSong = song
        audioPlayer?.play()
        isPlaying = true
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
    }
    
    // 清理当前播放资源
    private func cleanupCurrentPlayback() {
        // 暂停当前播放
        audioPlayer?.pause()
        
        // 移除时间观察者
        if let observer = timeObserver {
            audioPlayer?.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        // 移除所有通知
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    // 播放结束处理
    @objc private func playerDidFinishPlaying(notification: Notification) {
        // 在主线程执行，确保UI更新安全
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let currentSong = self.currentSong,
                  let currentIndex = self.playlist.firstIndex(where: { $0.id == currentSong.id }),
                  !self.playlist.isEmpty else { return }
                  
            // 计算下一首歌曲索引
            let nextIndex = (currentIndex + 1) % self.playlist.count
            let nextSong = self.playlist[nextIndex]
            // 播放下一首
            self.play(song: nextSong)
        }
    }
    
    private func setupPlayerObservers() {
        // 移除之前的观察者
        if let observer = timeObserver {
            audioPlayer?.removeTimeObserver(observer)
        }
        
        // 添加新的时间观察者
        timeObserver = audioPlayer?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self, let duration = self.audioPlayer?.currentItem?.duration else { return }
            if !duration.seconds.isNaN && duration.seconds > 0 {
                self.progress = time.seconds / duration.seconds
            } else {
                self.progress = 0
            }
        }
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
    
    // 处理从播放列表中删除歌曲
    func removeSongFromPlaylist(_ song: SecureSong) {
        if let index = playlist.firstIndex(where: { $0.id == song.id }) {
            // 如果删除的是当前播放的歌曲，先停止播放
            if currentSong?.id == song.id {
                stop()
                currentSong = nil
            }
            
            // 从安全资源列表中移除
            if let urlIndex = securityScopedURLs.firstIndex(of: song.fileURL) {
                song.fileURL.stopAccessingSecurityScopedResource()
                securityScopedURLs.remove(at: urlIndex)
            }
            
            // 从播放列表中移除
            playlist.remove(at: index)
        }
    }
    
    deinit {
        cleanupCurrentPlayback()
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
        viewModel.removeSongFromPlaylist(song)
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
