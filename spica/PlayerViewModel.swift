import SwiftUI
import AVKit
import Combine
import AppKit
import MediaPlayer

class PlayerViewModel: NSObject, ObservableObject {
    @Published var currentSong: SecureSong?
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var playlist: [SecureSong] = []
    @Published var errorMessage: String?
    @Published var audioInfo: AudioInfo = AudioInfo()
    
    public var audioPlayer: AVPlayer?
    private var timeObserver: Any?
    private var securityScopedURLs = [URL]()
    private var playerItemObservation: NSKeyValueObservation?
    private var mediaRemoteCommandCenter: MPRemoteCommandCenter
    private var nowPlayingInfoCenter: MPNowPlayingInfoCenter
    
    // 音频格式信息结构体
    struct AudioInfo {
        var bitrate: Int = 0
        var sampleRate: Double = 0
        var fileFormat: String = ""
        var channels: Int = 0
        var fileSize: Int64 = 0
        var formattedFileSize: String {
            ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
        }
    }
    
    override init() {
        // 初始化媒体控制中心
        mediaRemoteCommandCenter = MPRemoteCommandCenter.shared()
        nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
        
        super.init()
        
        // 设置媒体控制命令
        setupMediaRemoteCommands()
    }
    
    // 设置媒体远程控制命令
    private func setupMediaRemoteCommands() {
        mediaRemoteCommandCenter.togglePlayPauseCommand.addTarget { [weak self] event in
            guard let self = self, let currentSong = self.currentSong else {
                return .noActionableNowPlayingItem
            }
            
            if !self.isPlaying {
                self.play(song: currentSong)
                return .success
            }
            else {
                self.pause()
                return .success
            }
        }
        
        // 下一曲命令
        mediaRemoteCommandCenter.nextTrackCommand.addTarget { [weak self] event in
            guard let self = self,
                  let currentSong = self.currentSong,
                  let currentIndex = self.playlist.firstIndex(where: { $0.id == currentSong.id }),
                  !self.playlist.isEmpty else {
                return .noActionableNowPlayingItem
            }
            
            let nextIndex = (currentIndex + 1) % self.playlist.count
            let nextSong = self.playlist[nextIndex]
            self.play(song: nextSong)
            return .success
        }
        
        // 上一曲命令
        mediaRemoteCommandCenter.previousTrackCommand.addTarget { [weak self] event in
            guard let self = self,
                  let currentSong = self.currentSong,
                  let currentIndex = self.playlist.firstIndex(where: { $0.id == currentSong.id }),
                  !self.playlist.isEmpty else {
                return .noActionableNowPlayingItem
            }
            
            let previousIndex = (currentIndex - 1 + self.playlist.count) % self.playlist.count
            let previousSong = self.playlist[previousIndex]
            self.play(song: previousSong)
            return .success
        }
        
        // 跳转命令
        mediaRemoteCommandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                  let player = self.audioPlayer,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            
            let time = CMTime(seconds: positionEvent.positionTime, preferredTimescale: 600)
            player.seek(to: time)
            return .success
        }
    }
    
    // 更新正在播放信息
    public func updateNowPlayingInfo() {
        guard let song = currentSong else {
            nowPlayingInfoCenter.nowPlayingInfo = nil
            return
        }
        
        var nowPlayingInfo = [String: Any]()
        
        // 基本信息
        nowPlayingInfo[MPMediaItemPropertyTitle] = song.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = song.artist
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = song.album
        
        // 设置专辑封面
        if let artwork = song.artwork {
            let albumArt = MPMediaItemArtwork(boundsSize: CGSize(width: 600, height: 600)) { size in
                return artwork
            }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = albumArt
        }
        
        // 播放进度相关信息
        if let player = audioPlayer {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime().seconds
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = song.duration
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
        }
        
        // 更新信息
        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
    }
    
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
                
                // 获取持续时间
                let asset = AVURLAsset(url: url)
                var duration: Double = 0
                do {
                    let durationValue = try await asset.load(.duration)
                    duration = CMTimeGetSeconds(durationValue)
                    if duration.isNaN { duration = 0 }
                } catch {
                    duration = 0
                }
                
                // 使用 Python 脚本解析标签
                let pythonHelper = PythonScriptHelper.shared
                
                // 创建任务组以等待异步完成
                await withCheckedContinuation { continuation in
                    pythonHelper.runTagParser(for: url) { title, artist, album, lyrics, artwork in
                        let finalTitle = title ?? url.deletingPathExtension().lastPathComponent
                        let finalArtist = artist ?? "未知艺术家"
                        let finalAlbum = album ?? "未知专辑"
                        let finalLyrics = lyrics ?? []
                        
                        let newSong = SecureSong(
                            title: finalTitle,
                            artist: finalArtist,
                            album: finalAlbum,
                            duration: duration,
                            fileURL: url,
                            artwork: artwork,
                            lyrics: finalLyrics,
                            securityScoped: true
                        )
                        
                        Task { @MainActor in
                            self.playlist.append(newSong)
                        }
                        
                        continuation.resume()
                    }
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
            updateNowPlayingInfo()
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
        
        // 获取并更新音频格式信息
        extractAudioInfo(from: song.fileURL)
        
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
        
        // 更新媒体控制信息
        updateNowPlayingInfo()
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        
        // 更新媒体控制信息
        if var nowPlayingInfo = nowPlayingInfoCenter.nowPlayingInfo {
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0
            nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
        }
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
            guard let self = self, let duration = self.audioPlayer?.currentItem?.duration else { return }
            if !duration.seconds.isNaN && duration.seconds > 0 {
                self.progress = time.seconds / duration.seconds
                
                // 更新媒体控制中的播放进度
                if var nowPlayingInfo = self.nowPlayingInfoCenter.nowPlayingInfo {
                    nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = time.seconds
                    self.nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
                }
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
        
        // 清除媒体控制信息
        nowPlayingInfoCenter.nowPlayingInfo = nil
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
    
    // 提取音频格式信息
    private func extractAudioInfo(from url: URL) {
        // 重置音频信息 - 在主线程上操作
        DispatchQueue.main.async {
            self.audioInfo = AudioInfo()
        }
        
        // 获取文件大小
        do {
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
            if let fileSize = resourceValues.fileSize {
                let fileSizeValue = Int64(fileSize)
                // 确保在主线程更新
                DispatchQueue.main.async {
                    self.audioInfo.fileSize = fileSizeValue
                }
            }
        } catch {
            print("无法获取文件大小: \(error)")
        }
        
        // 提取音频格式信息
        let asset = AVURLAsset(url: url)
        
        // 获取文件格式 - 确保在主线程更新
        let fileFormat = url.pathExtension.uppercased()
        DispatchQueue.main.async {
            self.audioInfo.fileFormat = fileFormat
        }
        
        Task {
            do {
                if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first {
                    // 获取音频格式描述
                    let formatDescriptions = try await audioTrack.load(.formatDescriptions)
                    
                    // 临时存储获取的值
                    var tempSampleRate: Double = 0
                    var tempChannels: Int = 0
                    
                    if let formatDescription = formatDescriptions.first {
                        // 获取采样率
                        if let sampleRate = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee.mSampleRate {
                            tempSampleRate = sampleRate
                        }
                        
                        // 获取声道数
                        if let channelsPerFrame = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee.mChannelsPerFrame {
                            tempChannels = Int(channelsPerFrame)
                        }
                    }
                    
                    // 估算比特率
                    let duration = try await asset.load(.duration)
                    let durationInSeconds = CMTimeGetSeconds(duration)
                    var tempBitrate: Int = 0
                    
                    if durationInSeconds > 0 {
                        var fileSize: Int64 = 0
                        // 在主线程获取当前的文件大小
                        await MainActor.run {
                            fileSize = self.audioInfo.fileSize
                        }
                        tempBitrate = Int(Double(fileSize) * 8.0 / durationInSeconds / 1000.0)
                    }
                    
                    // 所有属性更新都在主线程进行
                    await MainActor.run {
                        self.audioInfo.sampleRate = tempSampleRate
                        self.audioInfo.channels = tempChannels
                        self.audioInfo.bitrate = tempBitrate
                    }
                }
            } catch {
                print("加载音频信息错误: \(error)")
            }
        }
    }
    
    deinit {
        cleanupCurrentPlayback()
        releaseSecurityScopedResources()
        
        // 清除媒体控制命令
        mediaRemoteCommandCenter.playCommand.removeTarget(nil)
        mediaRemoteCommandCenter.pauseCommand.removeTarget(nil)
        mediaRemoteCommandCenter.nextTrackCommand.removeTarget(nil)
        mediaRemoteCommandCenter.previousTrackCommand.removeTarget(nil)
        mediaRemoteCommandCenter.changePlaybackPositionCommand.removeTarget(nil)
    }
}
