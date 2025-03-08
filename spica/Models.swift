import SwiftUI
import AVKit
import AppKit

// 安全访问文件模型
struct SecureSong: Identifiable {
    let id = UUID()
    let title: String
    let artist: String
    let album: String
    let duration: Double
    let fileURL: URL
    let artwork: NSImage?
    var lyrics: [String] = []  // 保存歌词行
    var securityScoped: Bool = false
}
