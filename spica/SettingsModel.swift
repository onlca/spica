import Foundation
import Combine

class SettingsModel: ObservableObject {
    static let shared = SettingsModel()
    
    @Published var showLyricTimestamps: Bool {
        didSet {
            UserDefaults.standard.set(showLyricTimestamps, forKey: "showLyricTimestamps")
        }
    }
    
    @Published var showStatusBar: Bool {
        didSet {
            UserDefaults.standard.set(showStatusBar, forKey: "showStatusBar")
        }
    }
    
    @Published var musicFolderURL: URL? {
        didSet {
            if let url = musicFolderURL {
                // 启动访问权限（创建 bookmark 需要访问权限）
                let didStartAccessing = url.startAccessingSecurityScopedResource()
                
                // 保存 bookmark 数据
                do {
                    let bookmarkData = try url.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    UserDefaults.standard.set(bookmarkData, forKey: "musicFolderBookmark")
                } catch {
                    print("保存书签失败: \(error)")
                }
                
                // 停止访问权限
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            } else {
                UserDefaults.standard.removeObject(forKey: "musicFolderBookmark")
            }
        }
    }
    
    // 播放列表显示设置
    @Published var showPlaylistArtist = true {
        didSet {
            UserDefaults.standard.set(showPlaylistArtist, forKey: "ShowPlaylistArtist")
        }
    }
    
    @Published var showPlaylistAlbum = true {
        didSet {
            UserDefaults.standard.set(showPlaylistAlbum, forKey: "ShowPlaylistAlbum")
        }
    }
    
    @Published var showPlaylistDuration = true {
        didSet {
            UserDefaults.standard.set(showPlaylistDuration, forKey: "ShowPlaylistDuration")
        }
    }
    
    init() {
        self.showLyricTimestamps = UserDefaults.standard.bool(forKey: "showLyricTimestamps")
        self.showStatusBar = UserDefaults.standard.object(forKey: "showStatusBar") as? Bool ?? true
        
        // 从 UserDefaults 恢复音乐文件夹
        if let bookmarkData = UserDefaults.standard.data(forKey: "musicFolderBookmark") {
            do {
                var isStale = false
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                if !isStale {
                    self.musicFolderURL = url
                }
            } catch {
                print("恢复书签失败: \(error)")
            }
        }
    }
}
