import Foundation
import AVKit
import AppKit

class MusicLibraryManager {
    static let shared = MusicLibraryManager()
    
    private let cacheFileName = "music_library_cache.json"
    private var cacheURL: URL {
        // 使用应用支持目录存储缓存
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("无法访问应用支持目录")
        }
        
        // 创建应用专用目录
        let appDirectory = appSupport.appendingPathComponent("com.spica.musicplayer", isDirectory: true)
        
        // 确保目录存在
        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        
        return appDirectory.appendingPathComponent(cacheFileName)
    }
    
    // 获取缓存文件路径（用于调试）
    func getCachePath() -> String {
        return cacheURL.path
    }
    
    // 支持的音频格式
    private let supportedFormats = ["mp3", "flac", "m4a", "aac", "wav", "aiff", "alac", "ogg", "opus", "wma"]
    
    private init() {}
    
    // 加载音乐库：优先从缓存加载，首次扫描文件夹
    // 注意：调用者需要先启动 folderURL 的 security-scoped 访问
    func loadMusicLibrary(from folderURL: URL) async throws -> [SecureSong] {
        // 尝试从缓存加载
        if let cachedSongs = try? loadFromCache(folderURL: folderURL) {
            print("从缓存加载 \(cachedSongs.count) 首歌曲")
            return cachedSongs
        }
        
        // 缓存不存在或加载失败，扫描文件夹
        print("开始扫描音乐文件夹...")
        let songs = try await scanMusicFolder(folderURL: folderURL)
        
        // 保存到缓存
        try? saveToCache(songs: songs, folderURL: folderURL)
        
        return songs
    }
    
    // 强制刷新：重新扫描文件夹并更新缓存
    // 注意：调用者需要先启动 folderURL 的 security-scoped 访问
    func refreshMusicLibrary(from folderURL: URL) async throws -> [SecureSong] {
        print("刷新音乐库...")
        let songs = try await scanMusicFolder(folderURL: folderURL)
        
        // 更新缓存
        try? saveToCache(songs: songs, folderURL: folderURL)
        
        return songs
    }
    
    // 扫描文件夹中的所有音频文件
    private func scanMusicFolder(folderURL: URL) async throws -> [SecureSong] {
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        
        var songs: [SecureSong] = []
        var urls: [URL] = []
        
        // 收集所有音频文件
        while let fileURL = enumerator?.nextObject() as? URL {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  resourceValues.isRegularFile == true,
                  supportedFormats.contains(fileURL.pathExtension.lowercased()) else {
                continue
            }
            urls.append(fileURL)
        }
        
        print("找到 \(urls.count) 个音频文件")
        
        // 并发解析（使用 TaskGroup 提高效率）
        await withTaskGroup(of: SecureSong?.self) { group in
            for fileURL in urls {
                group.addTask {
                    return await self.parseSongMetadata(from: fileURL, baseFolderURL: folderURL)
                }
            }
            
            for await song in group {
                if let song = song {
                    songs.append(song)
                }
            }
        }
        
        print("成功解析 \(songs.count) 首歌曲")
        return songs
    }
    
    // 解析单个音频文件的元数据（不加载图片）
    private func parseSongMetadata(from fileURL: URL, baseFolderURL: URL) async -> SecureSong? {
        // 获取持续时间
        let asset = AVURLAsset(url: fileURL)
        var duration: Double = 0
        do {
            let durationValue = try await asset.load(.duration)
            duration = CMTimeGetSeconds(durationValue)
            if duration.isNaN { duration = 0 }
        } catch {
            duration = 0
        }
        
        // 解析标签（不加载图片）
        let tags: AudioTags
        do {
            tags = try await AudioTagParser.shared.parseTags(from: fileURL, loadArtwork: false)
        } catch {
            // 解析失败时使用默认值
            tags = AudioTags(
                title: fileURL.deletingPathExtension().lastPathComponent,
                artist: "未知艺术家",
                album: "未知专辑",
                trackNumber: 0,
                lyrics: [],
                artwork: nil
            )
        }
        
        return SecureSong(
            title: tags.title,
            artist: tags.artist,
            album: tags.album,
            duration: duration,
            fileURL: fileURL,
            artwork: nil,  // 初始不加载图片
            lyrics: tags.lyrics,
            securityScoped: false,
            tracknumber: tags.trackNumber
        )
    }
    
    // 按需加载歌曲的专辑封面
    func loadArtwork(for song: SecureSong) async -> NSImage? {
        do {
            let tags = try await AudioTagParser.shared.parseTags(from: song.fileURL, loadArtwork: true)
            return tags.artwork
        } catch {
            print("加载封面失败: \(error)")
            return nil
        }
    }
    
    // 保存到缓存
    private func saveToCache(songs: [SecureSong], folderURL: URL) throws {
        let cachedMetadata = songs.map { song -> CachedSongMetadata in
            let relativePath = song.fileURL.path.replacingOccurrences(of: folderURL.path + "/", with: "")
            return CachedSongMetadata(
                title: song.title,
                artist: song.artist,
                album: song.album,
                duration: song.duration,
                fileURLPath: relativePath,
                tracknumber: song.tracknumber,
                lyrics: song.lyrics.map { CachedSongMetadata.CachedLyricLine(timestamp: $0.timestamp, text: $0.text) }
            )
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(cachedMetadata)
        try data.write(to: cacheURL)
        
        print("已保存 \(songs.count) 首歌曲到缓存")
    }
    
    // 从缓存加载
    private func loadFromCache(folderURL: URL) throws -> [SecureSong] {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            throw NSError(domain: "MusicLibraryManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "缓存不存在"])
        }
        
        let data = try Data(contentsOf: cacheURL)
        let decoder = JSONDecoder()
        let cachedMetadata = try decoder.decode([CachedSongMetadata].self, from: data)
        
        // 转换为 SecureSong
        let songs = cachedMetadata.compactMap { metadata -> SecureSong? in
            let fileURL = folderURL.appendingPathComponent(metadata.fileURLPath)
            
            // 检查文件是否存在
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return nil
            }
            
            let lyrics = metadata.lyrics.map { LyricLine(timestamp: $0.timestamp, text: $0.text) }
            
            return SecureSong(
                title: metadata.title,
                artist: metadata.artist,
                album: metadata.album,
                duration: metadata.duration,
                fileURL: fileURL,
                artwork: nil,  // 从缓存加载时不加载图片
                lyrics: lyrics,
                securityScoped: false,
                tracknumber: metadata.tracknumber
            )
        }
        
        return songs
    }
    
    // 清除缓存
    func clearCache() {
        try? FileManager.default.removeItem(at: cacheURL)
        print("缓存已清除")
    }
}
