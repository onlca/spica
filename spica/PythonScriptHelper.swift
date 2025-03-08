import Foundation
import AppKit
import AVKit

class PythonScriptHelper {
    static let shared = PythonScriptHelper()
    
    private init() {}
    
    func runTagParser(for url: URL, completion: @escaping (String?, String?, String?, [LyricLine]?, NSImage?) -> Void) {
        // 确保Python脚本存在
        guard let scriptURL = Bundle.main.url(forResource: "TagParser", withExtension: "py") else {
            fallbackToAVFoundation(url: url, completion: completion)
            return
        }
        
        // 修改脚本执行方式，使用同步方式运行
        DispatchQueue.global(qos: .userInitiated).async {
            // 创建进程
            let task = Process()
            
            // 明确设置环境变量，避免PATH问题
            var environment = ProcessInfo.processInfo.environment
            environment["PYTHONIOENCODING"] = "utf-8"
            task.environment = environment
            
            // 设置Python路径和参数
            task.executableURL = URL(fileURLWithPath: "/opt/anaconda3/bin/python3")
            task.arguments = [scriptURL.path, url.path]
            
            // 设置管道
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            task.standardOutput = outputPipe
            task.standardError = errorPipe
            
            do {
                // 启动进程并等待完成
                try task.run()
                task.waitUntilExit()
                
                // 获取输出数据
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                
                if let output = String(data: outputData, encoding: .utf8),
                   !output.isEmpty,
                   let jsonLine = output.components(separatedBy: .newlines).first(where: { $0.starts(with: "{") }),
                   let jsonData = jsonLine.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                    
                    // 解析返回的标签数据
                    let title = json["title"] as? String
                    let artist = json["artist"] as? String
                    let album = json["album"] as? String
                    
                    // 解析歌词数据
                    var lyricLines: [LyricLine] = []
                    if let lyricsArray = json["lyrics"] as? [[String: Any]] {
                        for item in lyricsArray {
                            if let text = item["text"] as? String {
                                let time = item["time"] as? Double ?? -1
                                lyricLines.append(LyricLine(timestamp: time, text: text))
                            }
                        }
                    } else if let lyricsArray = json["lyrics"] as? [String] {
                        // 兼容无时间戳的纯文本歌词
                        lyricLines = lyricsArray.map { LyricLine(timestamp: -1, text: $0) }
                    }
                    
                    // 处理封面数据
                    var artworkData: Data? = nil
                    
                    // 检查JSON中是否有封面
                    if let artworkBase64 = json["artwork"] as? String,
                       let decodedData = Data(base64Encoded: artworkBase64) {
                        artworkData = decodedData
                    } else {
                        // 尝试从临时文件中读取封面
                        let tempArtworkPath = NSHomeDirectory() + "/Documents/spica_temp_artwork.json"
                        if FileManager.default.fileExists(atPath: tempArtworkPath) {
                            if let artworkFileData = try? Data(contentsOf: URL(fileURLWithPath: tempArtworkPath)),
                               let artworkJson = try? JSONSerialization.jsonObject(with: artworkFileData) as? [String: String],
                               let artworkBase64 = artworkJson["artwork"],
                               let decodedData = Data(base64Encoded: artworkBase64) {
                                artworkData = decodedData
                                try? FileManager.default.removeItem(atPath: tempArtworkPath)
                            }
                        }
                    }
                    
                    // 在主线程创建NSImage并回调结果
                    DispatchQueue.main.async {
                        let artwork = artworkData.flatMap { NSImage(data: $0) }
                        completion(title, artist, album, lyricLines, artwork)
                    }
                } else {
                    // 如果没有有效的JSON输出，使用AVFoundation
                    self.fallbackToAVFoundation(url: url, completion: completion)
                }
            } catch {
                self.fallbackToAVFoundation(url: url, completion: completion)
            }
        }
    }
    
    // 使用AVFoundation作为备用方案
    private func fallbackToAVFoundation(url: URL, completion: @escaping (String?, String?, String?, [LyricLine]?, NSImage?) -> Void) {
        let title = url.deletingPathExtension().lastPathComponent
        let artist = "未知艺术家"
        let album = "未知专辑"
        
        Task {
            let asset = AVURLAsset(url: url)
            do {
                // 获取常见元数据
                let metadata = try await asset.load(.commonMetadata)
                var artworkData: Data? = nil
                var finalTitle = title
                var finalArtist = artist
                var finalAlbum = album
                
                // 从元数据中提取信息
                for item in metadata {
                    if let commonKey = item.commonKey {
                        switch commonKey {
                        case .commonKeyTitle:
                            if let value = try await item.load(.stringValue) {
                                finalTitle = value
                            }
                        case .commonKeyArtist:
                            if let value = try await item.load(.stringValue) {
                                finalArtist = value
                            }
                        case .commonKeyAlbumName:
                            if let value = try await item.load(.stringValue) {
                                finalAlbum = value
                            }
                        case .commonKeyArtwork:
                            artworkData = try await item.load(.dataValue)
                        default:
                            break
                        }
                    }
                }
                
                // 创建不可变的本地副本
                let immutableArtworkData = artworkData
                let immutableTitle = finalTitle
                let immutableArtist = finalArtist
                let immutableAlbum = finalAlbum
                
                // 在主线程上创建NSImage并回调结果
                await MainActor.run {
                    let artwork = immutableArtworkData.flatMap { NSImage(data: $0) }
                    completion(immutableTitle, immutableArtist, immutableAlbum, [], artwork)
                }
            } catch {
                // 如果提取失败，返回默认值
                let immutableTitle = title
                let immutableArtist = artist
                let immutableAlbum = album
                
                await MainActor.run {
                    completion(immutableTitle, immutableArtist, immutableAlbum, [], nil)
                }
            }
        }
    }
}
