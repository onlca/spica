import Foundation
import AppKit

// MARK: - 音频标签数据模型
struct AudioTags {
    var title: String
    var artist: String
    var album: String
    var trackNumber: Int
    var lyrics: [LyricLine]
    var artwork: NSImage?
}

// MARK: - 主解析器类
class AudioTagParser {
    static let shared = AudioTagParser()
    
    private init() {}
    
    /// 解析音频文件的标签信息
    func parseTags(from url: URL) async throws -> AudioTags {
        let fileExtension = url.pathExtension.lowercased()
        
        switch fileExtension {
        case "mp3":
            return try await parseMP3Tags(from: url)
        case "flac":
            return try await parseFLACTags(from: url)
        default:
            throw AudioTagError.unsupportedFormat
        }
    }
    
    // MARK: - MP3/ID3 解析
    private func parseMP3Tags(from url: URL) async throws -> AudioTags {
        let data = try Data(contentsOf: url)
        let parser = ID3Parser(data: data)
        return try parser.parse()
    }
    
    // MARK: - FLAC 解析
    private func parseFLACTags(from url: URL) async throws -> AudioTags {
        let data = try Data(contentsOf: url)
        let parser = FLACParser(data: data)
        return try parser.parse()
    }
}

// MARK: - 错误类型
enum AudioTagError: Error {
    case unsupportedFormat
    case invalidFileFormat
    case id3HeaderNotFound
    case corruptedData
    case unsupportedVersion
    
    var localizedDescription: String {
        switch self {
        case .unsupportedFormat:
            return "不支持的文件格式"
        case .invalidFileFormat:
            return "无效的文件格式"
        case .id3HeaderNotFound:
            return "未找到 ID3 标签头"
        case .corruptedData:
            return "数据损坏"
        case .unsupportedVersion:
            return "不支持的标签版本"
        }
    }
}

// MARK: - ID3 解析器
class ID3Parser {
    private let data: Data
    private var offset: Int = 0
    
    init(data: Data) {
        self.data = data
    }
    
    func parse() throws -> AudioTags {
        // 查找 ID3v2 标签
        guard data.count >= 10,
              data[0] == 0x49,  // 'I'
              data[1] == 0x44,  // 'D'
              data[2] == 0x33   // '3'
        else {
            throw AudioTagError.id3HeaderNotFound
        }
        
        let majorVersion = data[3]
        let _ = data[4]  // minorVersion
        let flags = data[5]
        
        // 解析标签大小（使用 synchsafe integer）
        let tagSize = synchsafeInt(
            data[6], data[7], data[8], data[9]
        )
        
        offset = 10
        
        // 检查是否有扩展头
        if flags & 0x40 != 0 {
            // 跳过扩展头
            if data.count >= offset + 4 {
                let extHeaderSize = synchsafeInt(
                    data[offset], data[offset + 1],
                    data[offset + 2], data[offset + 3]
                )
                offset += Int(extHeaderSize)
            }
        }
        
        var title: String?
        var artist: String?
        var album: String?
        var trackNumber: Int = 0
        var lyricsText: String?
        var artworkData: Data?
        
        // 解析帧
        let tagEnd = min(10 + Int(tagSize), data.count)
        
        while offset + 10 <= tagEnd {
            // 读取帧头
            let frameIDBytes = data[offset..<offset+4]
            let frameID = String(data: frameIDBytes, encoding: .isoLatin1) ?? ""
            
            // 如果遇到填充，停止解析
            if frameID.first == "\0" || frameID.isEmpty {
                break
            }
            
            offset += 4
            
            // 读取帧大小
            let frameSize: Int
            if majorVersion >= 4 {
                frameSize = Int(synchsafeInt(
                    data[offset], data[offset + 1],
                    data[offset + 2], data[offset + 3]
                ))
            } else {
                frameSize = Int(data[offset]) << 24 |
                           Int(data[offset + 1]) << 16 |
                           Int(data[offset + 2]) << 8 |
                           Int(data[offset + 3])
            }
            
            offset += 4
            
            // 读取帧标志
            let _ = (data[offset] << 8) | data[offset + 1]  // frameFlags
            offset += 2
            
            guard frameSize > 0, offset + frameSize <= data.count else {
                break
            }
            
            let frameData = data[offset..<offset + frameSize]
            
            // 解析特定帧
            switch frameID {
            case "TIT2": // 标题
                title = decodeTextFrame(frameData)
            case "TPE1": // 艺术家
                artist = decodeTextFrame(frameData)
            case "TALB": // 专辑
                album = decodeTextFrame(frameData)
            case "TRCK": // 音轨号
                if let trackStr = decodeTextFrame(frameData) {
                    // 提取数字部分（例如 "1/12" -> 1）
                    let components = trackStr.split(separator: "/")
                    if let first = components.first,
                       let num = Int(first) {
                        trackNumber = num
                    }
                }
            case "USLT": // 非同步歌词
                lyricsText = decodeUnsyncedLyrics(frameData)
            case "APIC": // 封面图片
                artworkData = decodeAPIC(frameData)
            default:
                break
            }
            
            offset += frameSize
        }
        
        // 解析歌词时间戳
        let lyrics = parseLyrics(lyricsText ?? "")
        
        // 创建封面图像
        let artwork = artworkData.flatMap { NSImage(data: $0) }
        
        return AudioTags(
            title: title ?? "未知标题",
            artist: artist ?? "未知艺术家",
            album: album ?? "未知专辑",
            trackNumber: trackNumber,
            lyrics: lyrics,
            artwork: artwork
        )
    }
    
    // MARK: - 辅助方法
    
    /// 解码 synchsafe integer（ID3v2 特殊格式）
    private func synchsafeInt(_ b1: UInt8, _ b2: UInt8, _ b3: UInt8, _ b4: UInt8) -> UInt32 {
        return UInt32(b1 & 0x7F) << 21 |
               UInt32(b2 & 0x7F) << 14 |
               UInt32(b3 & 0x7F) << 7 |
               UInt32(b4 & 0x7F)
    }
    
    /// 解码文本帧
    private func decodeTextFrame(_ data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        
        let encoding = data[data.startIndex]
        let textData = data.dropFirst()
        
        var text: String?
        switch encoding {
        case 0: // ISO-8859-1
            text = String(data: textData, encoding: .isoLatin1)
        case 1: // UTF-16 with BOM
            text = String(data: textData, encoding: .utf16)
        case 2: // UTF-16BE without BOM
            text = String(data: textData, encoding: .utf16BigEndian)
        case 3: // UTF-8
            text = String(data: textData, encoding: .utf8)
        default:
            return nil
        }
        
        // 移除 null 字符和首尾空白，但保留换行符
        return text?.replacingOccurrences(of: "\0", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 解码非同步歌词帧 (USLT)
    private func decodeUnsyncedLyrics(_ data: Data) -> String? {
        guard data.count >= 4 else { return nil }
        
        let encoding = data[data.startIndex]
        // 跳过语言代码（3字节）
        var pos = data.startIndex + 4
        
        // 跳过描述符（以 null 结尾的字符串）
        // 注意：对于 UTF-16 编码，null 终止符是 2 字节
        if encoding == 1 || encoding == 2 {
            // UTF-16: 需要跳过双字节 null 终止符
            while pos + 1 < data.endIndex && !(data[pos] == 0 && data[pos + 1] == 0) {
                pos += 2
            }
            pos += 2 // 跳过双字节 null
        } else {
            // ISO-8859-1 或 UTF-8: 单字节 null 终止符
            while pos < data.endIndex && data[pos] != 0 {
                pos += 1
            }
            pos += 1 // 跳过单字节 null
        }
        
        guard pos < data.endIndex else { return nil }
        
        let lyricsData = data[pos...]
        
        var lyrics: String?
        switch encoding {
        case 0: // ISO-8859-1
            lyrics = String(data: lyricsData, encoding: .isoLatin1)
        case 1: // UTF-16 with BOM
            lyrics = String(data: lyricsData, encoding: .utf16)
        case 2: // UTF-16BE without BOM
            lyrics = String(data: lyricsData, encoding: .utf16BigEndian)
        case 3: // UTF-8
            lyrics = String(data: lyricsData, encoding: .utf8)
        default:
            return nil
        }
        
        // 只移除字符串末尾的 null 字符，保留换行符
        return lyrics?.replacingOccurrences(of: "\0", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
    }
    
    /// 解码 APIC 帧（封面图片）
    private func decodeAPIC(_ data: Data) -> Data? {
        guard data.count > 5 else { return nil }
        
        let _ = data[data.startIndex]  // encoding
        var pos = data.startIndex + 1
        
        // 读取 MIME 类型（null 结尾的字符串）
        while pos < data.endIndex && data[pos] != 0 {
            pos += 1
        }
        pos += 1 // 跳过 null
        
        guard pos < data.endIndex else { return nil }
        
        // 跳过图片类型（1字节）
        pos += 1
        
        // 跳过描述（null 结尾的字符串）
        while pos < data.endIndex && data[pos] != 0 {
            pos += 1
        }
        pos += 1 // 跳过 null
        
        guard pos < data.endIndex else { return nil }
        
        // 剩余数据就是图片数据
        return data[pos...]
    }
    
    /// 解析带时间戳的歌词
    private func parseLyrics(_ text: String) -> [LyricLine] {
        let lines = text.components(separatedBy: .newlines)
        var result: [LyricLine] = []
        
        // LRC 格式：[mm:ss.xx]歌词文本
        let pattern = #"\[(\d+):(\d+)(?:\.(\d+))?\](.*)$"#
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
                
                // 提取分钟
                guard let minutesRange = Range(match.range(at: 1), in: trimmed),
                      let minutes = Int(trimmed[minutesRange]) else { continue }
                
                // 提取秒
                guard let secondsRange = Range(match.range(at: 2), in: trimmed),
                      let seconds = Int(trimmed[secondsRange]) else { continue }
                
                // 提取歌词文本
                guard let textRange = Range(match.range(at: 4), in: trimmed) else { continue }
                let text = String(trimmed[textRange]).trimmingCharacters(in: .whitespaces)
                
                let timestamp = Double(minutes * 60 + seconds)
                result.append(LyricLine(timestamp: timestamp, text: text))
            } else {
                // 没有时间戳的歌词
                result.append(LyricLine(timestamp: -1, text: trimmed))
            }
        }
        
        return result
    }
}

// MARK: - FLAC 解析器
class FLACParser {
    private let data: Data
    private var offset: Int = 0
    
    init(data: Data) {
        self.data = data
    }
    
    func parse() throws -> AudioTags {
        // 验证 FLAC 标识
        guard data.count >= 4,
              data[0] == 0x66, // 'f'
              data[1] == 0x4C, // 'L'
              data[2] == 0x61, // 'a'
              data[3] == 0x43  // 'C'
        else {
            throw AudioTagError.invalidFileFormat
        }
        
        offset = 4
        
        var title: String?
        var artist: String?
        var album: String?
        var trackNumber: Int = 0
        var lyricsText: String?
        var artworkData: Data?
        
        // 解析元数据块
        var isLastBlock = false
        
        while !isLastBlock && offset + 4 <= data.count {
            let blockHeader = data[offset]
            isLastBlock = (blockHeader & 0x80) != 0
            let blockType = blockHeader & 0x7F
            
            offset += 1
            
            // 读取块大小（24位大端）
            let blockSize = Int(data[offset]) << 16 |
                           Int(data[offset + 1]) << 8 |
                           Int(data[offset + 2])
            offset += 3
            
            guard offset + blockSize <= data.count else {
                throw AudioTagError.corruptedData
            }
            
            let blockData = data[offset..<offset + blockSize]
            
            switch blockType {
            case 4: // Vorbis Comment
                let comments = try parseVorbisComment(blockData)
                title = comments["TITLE"]?.first
                artist = comments["ARTIST"]?.first
                album = comments["ALBUM"]?.first
                lyricsText = comments["LYRICS"]?.first
                if let trackStr = comments["TRACKNUMBER"]?.first,
                   let num = Int(trackStr) {
                    trackNumber = num
                }
                
            case 6: // Picture
                artworkData = parsePictureBlock(blockData)
                
            default:
                break
            }
            
            offset += blockSize
        }
        
        // 解析歌词
        let lyrics = parseLyrics(lyricsText ?? "")
        
        // 创建封面
        let artwork = artworkData.flatMap { NSImage(data: $0) }
        
        return AudioTags(
            title: title ?? "未知标题",
            artist: artist ?? "未知艺术家",
            album: album ?? "未知专辑",
            trackNumber: trackNumber,
            lyrics: lyrics,
            artwork: artwork
        )
    }
    
    // MARK: - 辅助方法
    
    /// 解析 Vorbis Comment
    private func parseVorbisComment(_ data: Data) throws -> [String: [String]] {
        var pos = data.startIndex
        var comments: [String: [String]] = [:]
        
        // 跳过 vendor string
        guard pos + 4 <= data.endIndex else { return comments }
        let vendorLength = readLittleEndianUInt32(from: data, at: pos)
        pos += 4 + Int(vendorLength)
        
        // 读取注释数量
        guard pos + 4 <= data.endIndex else { return comments }
        let commentCount = readLittleEndianUInt32(from: data, at: pos)
        pos += 4
        
        // 解析每个注释
        for _ in 0..<commentCount {
            guard pos + 4 <= data.endIndex else { break }
            let commentLength = readLittleEndianUInt32(from: data, at: pos)
            pos += 4
            
            guard pos + Int(commentLength) <= data.endIndex else { break }
            let commentData = data[pos..<pos + Int(commentLength)]
            
            if let commentStr = String(data: commentData, encoding: .utf8) {
                let parts = commentStr.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    let key = String(parts[0]).uppercased()
                    let value = String(parts[1])
                    comments[key, default: []].append(value)
                }
            }
            
            pos += Int(commentLength)
        }
        
        return comments
    }
    
    /// 解析 Picture 元数据块
    private func parsePictureBlock(_ data: Data) -> Data? {
        var pos = data.startIndex
        
        // 跳过图片类型（4字节）
        pos += 4
        
        guard pos + 4 <= data.endIndex else { return nil }
        
        // 读取 MIME 类型长度
        let mimeLength = readBigEndianUInt32(from: data, at: pos)
        pos += 4 + Int(mimeLength)
        
        guard pos + 4 <= data.endIndex else { return nil }
        
        // 读取描述长度
        let descLength = readBigEndianUInt32(from: data, at: pos)
        pos += 4 + Int(descLength)
        
        // 跳过宽度、高度、颜色深度、颜色数量（嚄4字节）
        pos += 16
        
        guard pos + 4 <= data.endIndex else { return nil }
        
        // 读取图片数据长度
        let pictureLength = readBigEndianUInt32(from: data, at: pos)
        pos += 4
        
        guard pos + Int(pictureLength) <= data.endIndex else { return nil }
        
        return data[pos..<pos + Int(pictureLength)]
    }
    
    /// 读取小端 32 位无符号整数
    private func readLittleEndianUInt32(from data: Data, at offset: Data.Index) -> UInt32 {
        return UInt32(data[offset]) |
               UInt32(data[offset + 1]) << 8 |
               UInt32(data[offset + 2]) << 16 |
               UInt32(data[offset + 3]) << 24
    }
    
    /// 读取大端 32 位无符号整数
    private func readBigEndianUInt32(from data: Data, at offset: Data.Index) -> UInt32 {
        return UInt32(data[offset]) << 24 |
               UInt32(data[offset + 1]) << 16 |
               UInt32(data[offset + 2]) << 8 |
               UInt32(data[offset + 3])
    }
    
    /// 解析带时间戳的歌词
    private func parseLyrics(_ text: String) -> [LyricLine] {
        let lines = text.components(separatedBy: .newlines)
        var result: [LyricLine] = []
        
        // LRC 格式：[mm:ss.xx]歌词文本
        let pattern = #"\[(\d+):(\d+)(?:\.(\d+))?\](.*)$"#
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
                
                // 提取分钟
                guard let minutesRange = Range(match.range(at: 1), in: trimmed),
                      let minutes = Int(trimmed[minutesRange]) else { continue }
                
                // 提取秒
                guard let secondsRange = Range(match.range(at: 2), in: trimmed),
                      let seconds = Int(trimmed[secondsRange]) else { continue }
                
                // 提取歌词文本
                guard let textRange = Range(match.range(at: 4), in: trimmed) else { continue }
                let text = String(trimmed[textRange]).trimmingCharacters(in: .whitespaces)
                
                let timestamp = Double(minutes * 60 + seconds)
                result.append(LyricLine(timestamp: timestamp, text: text))
            } else {
                // 没有时间戳的歌词
                result.append(LyricLine(timestamp: -1, text: trimmed))
            }
        }
        
        return result
    }
}
