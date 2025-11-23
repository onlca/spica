import SwiftUI
import AVKit
import AppKit

// 歌词行结构
struct LyricLine: Identifiable {
    let id = UUID()
    let timestamp: Double  // 秒为单位的时间戳，-1表示无时间标签
    let text: String       // 歌词文本
}

// 安全访问文件模型
struct SecureSong: Identifiable {
    let id = UUID()
    let title: String
    let artist: String
    let album: String
    let duration: Double
    let fileURL: URL
    var artwork: NSImage?  // 可变，支持按需加载
    var lyrics: [LyricLine] = []  // 保存带时间戳的歌词
    var securityScoped: Bool = false
    var tracknumber: Int
}

// 缓存的歌曲元数据（不包含图片）
struct CachedSongMetadata: Codable {
    let title: String
    let artist: String
    let album: String
    let duration: Double
    let fileURLPath: String  // 使用相对路径
    let tracknumber: Int
    let lyrics: [CachedLyricLine]
    
    struct CachedLyricLine: Codable {
        let timestamp: Double
        let text: String
    }
}

// 播放状态（用于持久化）
struct PlaybackState: Codable {
    let currentSongURLPath: String?  // 当前播放歌曲的文件路径
    let playlistOrder: [String]      // 播放列表顺序（文件路径数组）
    
    static let userDefaultsKey = "PlaybackState"
}
