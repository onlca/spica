import Foundation
import AppKit
import AVKit

class PythonScriptHelper {
    static let shared = PythonScriptHelper()
    
    private init() {}
    
    func runTagParser(for url: URL, completion: @escaping (String?, String?, String?, [LyricLine]?, NSImage?) -> Void) {
        // 确保Python脚本存在
        guard let scriptURL = Bundle.main.url(forResource: "TagParser", withExtension: "py") else {
            print("错误: 找不到TagParser.py脚本")
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
            
            // 脚本路径参数
            let scriptPath = scriptURL.path
            let filePath = url.path
            task.arguments = [scriptPath, filePath]
            
            // 设置管道
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            task.standardOutput = outputPipe
            task.standardError = errorPipe
            
            do {
                // 启动进程
                try task.run()
                
                // 同步等待进程完成
                task.waitUntilExit()
                
                // 捕获错误输出
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                if let errorOutput = String(data: errorData, encoding: .utf8), !errorOutput.isEmpty {
                    print("Python脚本错误: \(errorOutput)")
                }
                
                // 捕获标准输出
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                
                if let output = String(data: outputData, encoding: .utf8), !output.isEmpty {
                    print("Python脚本原始输出: \(output)")
                    
                    // 处理输出中可能的多行JSON问题
                    if let jsonLine = output.components(separatedBy: .newlines).first(where: { $0.starts(with: "{") }) {
                        print("提取的JSON: \(jsonLine)")
                        
                        do {
                            if let jsonData = jsonLine.data(using: .utf8),
                               let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                                
                                // 检查是否有错误
                                if let error = json["error"] as? String {
                                    print("处理标签时出错: \(error)")
                                }
                                
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
                                
                                // 处理封面数据，而不是直接创建NSImage
                                var artworkData: Data? = nil
                                
                                // 检查JSON中是否有封面
                                if let artworkBase64 = json["artwork"] as? String,
                                   let decodedData = Data(base64Encoded: artworkBase64) {
                                    artworkData = decodedData
                                } else {
                                    // 尝试从临时文件中读取封面
                                    let tempArtworkPath = NSHomeDirectory() + "/Documents/spica_temp_artwork.json"
                                    if FileManager.default.fileExists(atPath: tempArtworkPath) {
                                        do {
                                            let artworkFileData = try Data(contentsOf: URL(fileURLWithPath: tempArtworkPath))
                                            if let artworkJson = try JSONSerialization.jsonObject(with: artworkFileData) as? [String: String],
                                               let artworkBase64 = artworkJson["artwork"],
                                               let decodedData = Data(base64Encoded: artworkBase64) {
                                                artworkData = decodedData
                                                
                                                // 删除临时文件
                                                try? FileManager.default.removeItem(atPath: tempArtworkPath)
                                            }
                                        } catch {
                                            print("读取临时封面文件失败: \(error)")
                                        }
                                    }
                                }
                                
                                // 在主线程创建NSImage并回调结果
                                DispatchQueue.main.async {
                                    let artwork = artworkData.flatMap { NSImage(data: $0) }
                                    completion(title, artist, album, lyricLines, artwork)
                                }
                                return
                            }
                        } catch {
                            print("解析JSON失败: \(error)")
                        }
                    }
                }
                
                // 如果没有有效的JSON输出，使用AVFoundation
                self.fallbackToAVFoundation(url: url, completion: completion)
                
            } catch {
                print("运行Python脚本失败: \(error.localizedDescription)")
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
                
                // 在主线程上创建NSImage并回调所有结果
                await MainActor.run {
                    let artwork = artworkData.flatMap { NSImage(data: $0) }
                    completion(finalTitle, finalArtist, finalAlbum, [], artwork)
                }
            } catch {
                print("AVFoundation元数据提取失败: \(error)")
                // 如果提取失败，返回默认值
                await MainActor.run {
                    completion(title, artist, album, [], nil)
                }
            }
        }
    }
}
