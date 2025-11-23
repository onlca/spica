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
    @Published var isLoadingLibrary = false
    
    // 排序类型枚举
    enum SortType {
        case title
        case artist
        case album
        case random
    }
    
    public var audioPlayer: AVPlayer?
    private var timeObserver: Any?
    private var securityScopedURLs = [URL]()
    private var playerItemObservation: NSKeyValueObservation?
    private var mediaRemoteCommandCenter: MPRemoteCommandCenter
    private var nowPlayingInfoCenter: MPNowPlayingInfoCenter
    private var musicFolderURL: URL?  // 保存音乐文件夹 URL 用于访问权限
    
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
        
        // 启动时自动加载音乐库
        Task {
            await loadMusicLibrary()
        }
    }
    
    // 加载音乐库
    func loadMusicLibrary() async {
        guard let folderURL = SettingsModel.shared.musicFolderURL else {
            return
        }
        
        // 停止之前的文件夹访问
        if let oldFolder = musicFolderURL {
            oldFolder.stopAccessingSecurityScopedResource()
        }
        
        // 启动新文件夹的访问权限
        guard folderURL.startAccessingSecurityScopedResource() else {
            await MainActor.run {
                self.errorMessage = "无法访问音乐文件夹"
            }
            return
        }
        
        await MainActor.run {
            isLoadingLibrary = true
            // 保存文件夹 URL（已经启动访问权限）
            self.musicFolderURL = folderURL
        }
        
        do {
            let songs = try await MusicLibraryManager.shared.loadMusicLibrary(from: folderURL)
            await MainActor.run {
                self.playlist = songs
                self.isLoadingLibrary = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "加载音乐库失败: \(error.localizedDescription)"
                self.isLoadingLibrary = false
            }
        }
    }
    
    // 刷新音乐库
    func refreshMusicLibrary() async {
        guard let folderURL = SettingsModel.shared.musicFolderURL else {
            return
        }
        
        await MainActor.run {
            isLoadingLibrary = true
        }
        
        do {
            let songs = try await MusicLibraryManager.shared.refreshMusicLibrary(from: folderURL)
            await MainActor.run {
                self.playlist = songs
                self.isLoadingLibrary = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "刷新音乐库失败: \(error.localizedDescription)"
                self.isLoadingLibrary = false
            }
        }
    }
    
    // 设置媒体远程控制命令
    private func setupMediaRemoteCommands() {
        // 启用播放/暂停切换命令
        mediaRemoteCommandCenter.togglePlayPauseCommand.isEnabled = true
        mediaRemoteCommandCenter.togglePlayPauseCommand.addTarget { [weak self] event in
            guard let self = self, let currentSong = self.currentSong else {
                return .noActionableNowPlayingItem
            }
            
            if self.isPlaying {
                self.pause()
            } else {
                self.play(song: currentSong)
            }
            return .success
        }
        
        // 启用播放命令
        mediaRemoteCommandCenter.playCommand.isEnabled = true
        mediaRemoteCommandCenter.playCommand.addTarget { [weak self] event in
            guard let self = self, let currentSong = self.currentSong else {
                return .noActionableNowPlayingItem
            }
            
            self.play(song: currentSong)
            return .success
        }
        
        // 启用暂停命令
        mediaRemoteCommandCenter.pauseCommand.isEnabled = true
        mediaRemoteCommandCenter.pauseCommand.addTarget { [weak self] event in
            guard let self = self else {
                return .noActionableNowPlayingItem
            }
            
            self.pause()
            return .success
        }
        
        // 下一曲命令
        mediaRemoteCommandCenter.nextTrackCommand.isEnabled = true
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
        mediaRemoteCommandCenter.previousTrackCommand.isEnabled = true
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
        mediaRemoteCommandCenter.changePlaybackPositionCommand.isEnabled = true
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
                
                // 使用新的 Swift 音频标签解析器
                let tags: AudioTags
                do {
                    tags = try await AudioTagParser.shared.parseTags(from: url)
                } catch {
                    // 解析失败时使用默认值
                    tags = AudioTags(
                        title: url.deletingPathExtension().lastPathComponent,
                        artist: "未知艺术家",
                        album: "未知专辑",
                        trackNumber: 0,
                        lyrics: [],
                        artwork: nil
                    )
                }
                
                let newSong = SecureSong(
                    title: tags.title,
                    artist: tags.artist,
                    album: tags.album,
                    duration: duration,
                    fileURL: url,
                    artwork: tags.artwork,
                    lyrics: tags.lyrics,
                    securityScoped: true,
                    tracknumber: tags.trackNumber
                )
                
                await MainActor.run {
                    self.playlist.append(newSong)
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
        
        // 如果是手动添加的歌曲（securityScoped=true），需要启动文件访问权限
        if song.securityScoped {
            guard song.fileURL.startAccessingSecurityScopedResource() else {
                errorMessage = "播放权限获取失败"
                return
            }
        }
        // 从音乐库加载的歌曲（securityScoped=false）使用文件夹的持续访问权限，不需要额外操作
        
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
        
        // 如果封面未加载，异步加载
        if song.artwork == nil {
            Task {
                if let artwork = await MusicLibraryManager.shared.loadArtwork(for: song) {
                    await MainActor.run {
                        // 更新 playlist 中的歌曲
                        if let index = self.playlist.firstIndex(where: { $0.id == song.id }) {
                            self.playlist[index].artwork = artwork
                        }
                        // 更新当前播放歌曲
                        if self.currentSong?.id == song.id {
                            self.currentSong?.artwork = artwork
                            self.updateNowPlayingInfo()
                        }
                    }
                }
            }
        }
        
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
    
    // 对播放列表进行排序
    func sortPlaylist(by sortType: SortType) {
        // 保存当前播放歌曲的ID以便排序后重新定位
        let currentSongId = currentSong?.id
        
        switch sortType {
        case .title:
            playlist.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .artist:
            playlist.sort { $0.artist.localizedCaseInsensitiveCompare($1.artist) == .orderedAscending }
        case .album:
        playlist.sort {
            if $0.album != $1.album {
                return $0.album.localizedCaseInsensitiveCompare($1.album) == .orderedAscending
            }
            return $0.tracknumber <= $1.tracknumber
        }
        case .random:
            playlist.shuffle()
        }
        
        // 如果需要，更新当前播放歌曲的引用
        if let id = currentSongId, let index = playlist.firstIndex(where: { $0.id == id }) {
            currentSong = playlist[index]
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
                    
                    // 从格式描述中获取信息
                    var sampleRate: Double = 0
                    var channels: Int = 0
                    
                    if let formatDescription = formatDescriptions.first {
                        // 获取采样率
                        if let sr = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee.mSampleRate {
                            sampleRate = sr
                        }
                        
                        // 获取声道数
                        if let ch = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee.mChannelsPerFrame {
                            channels = Int(ch)
                        }
                    }
                    
                    // 估算比特率
                    let duration = try await asset.load(.duration)
                    let durationInSeconds = CMTimeGetSeconds(duration)
                    
                    // 获取文件大小 - 在主线程获取并立即保存本地副本
                    let fileSize = await MainActor.run {
                        return self.audioInfo.fileSize
                    }
                    
                    // 使用本地变量计算比特率
                    let bitrate: Int
                    if durationInSeconds > 0 {
                        bitrate = Int(Double(fileSize) * 8.0 / durationInSeconds / 1000.0)
                    } else {
                        bitrate = 0
                    }
                    
                    // 一次性在主线程更新所有值，避免多次引用捕获的变量
                    await MainActor.run { [sampleRate, channels] in
                        self.audioInfo.sampleRate = sampleRate
                        self.audioInfo.channels = channels
                        self.audioInfo.bitrate = bitrate
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
        
        // 停止音乐文件夹访问
        if let folderURL = musicFolderURL {
            folderURL.stopAccessingSecurityScopedResource()
        }
        
        // 清除媒体控制命令
        mediaRemoteCommandCenter.togglePlayPauseCommand.removeTarget(nil)
        mediaRemoteCommandCenter.playCommand.removeTarget(nil)
        mediaRemoteCommandCenter.pauseCommand.removeTarget(nil)
        mediaRemoteCommandCenter.nextTrackCommand.removeTarget(nil)
        mediaRemoteCommandCenter.previousTrackCommand.removeTarget(nil)
        mediaRemoteCommandCenter.changePlaybackPositionCommand.removeTarget(nil)
    }
}
