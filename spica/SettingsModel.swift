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
            } else {
                UserDefaults.standard.removeObject(forKey: "musicFolderBookmark")
            }
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
