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
    let artwork: NSImage?
    var lyrics: [LyricLine] = []  // 保存带时间戳的歌词
    var securityScoped: Bool = false
    var tracknumber: Int
}
