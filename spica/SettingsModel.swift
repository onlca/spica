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
    
    init() {
        self.showLyricTimestamps = UserDefaults.standard.bool(forKey: "showLyricTimestamps")
        self.showStatusBar = UserDefaults.standard.object(forKey: "showStatusBar") as? Bool ?? true
    }
}
