import SwiftUI
import AVKit
import Combine
import AppKit

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
        Task {
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else {
                    await MainActor.run {
                        errorMessage = "文件访问被拒绝: \(url.lastPathComponent)"
                    }
                    continue
                }
                
                await MainActor.run {
                    securityScopedURLs.append(url)
                }
                
                // 使用新的 AVURLAsset 和异步加载 API
                let asset = AVURLAsset(url: url)
                
                // 加载持续时间
                var duration: Double = 0
                do {
                    let durationValue = try await asset.load(.duration)
                    duration = CMTimeGetSeconds(durationValue)
                    if duration.isNaN { duration = 0 }
                } catch {
                    print("无法加载持续时间：\(error.localizedDescription)")
                }
                
                // 提取元数据
                var title = url.deletingPathExtension().lastPathComponent
                var artist = "未知艺术家"
                var album = "未知专辑"
                var artwork: NSImage? = nil
                
                do {
                    // 加载元数据
                    let metadataItems = try await asset.load(.metadata)
                    
                    // 从元数据中获取艺术家
                    if let artistItem = metadataItems.first(where: { $0.commonKey == .commonKeyArtist }) {
                        let artistString = try await artistItem.load(.stringValue)
                        artist = artistString ?? artist
                    }
                    
                    // 从元数据中获取标题
                    if let titleItem = metadataItems.first(where: { $0.commonKey == .commonKeyTitle }) {
                        let titleString = try await titleItem.load(.stringValue)
                        title = titleString ?? title
                    }
                    
                    // 从元数据中获取专辑
                    if let albumItem = metadataItems.first(where: { $0.commonKey == .commonKeyAlbumName }) {
                        let albumString = try await albumItem.load(.stringValue)
                        album = albumString ?? album
                    }
                    
                    // 获取专辑封面
                    if let artworkItem = metadataItems.first(where: { $0.commonKey == .commonKeyArtwork }) {
                        if let data = try await artworkItem.load(.dataValue) {
                            artwork = NSImage(data: data)
                        }
                    }
                } catch {
                    print("无法加载元数据：\(error.localizedDescription)")
                }
                
                let newSong = SecureSong(
                    title: title,
                    artist: artist,
                    album: album,
                    duration: duration,
                    fileURL: url,
                    artwork: artwork,
                    securityScoped: true
                )
                
                await MainActor.run {
                    playlist.append(newSong)
                }
            }
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
