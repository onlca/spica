import Foundation
import Combine

class SettingsModel: ObservableObject {
    static let shared = SettingsModel()
    
    @Published var showLyricTimestamps: Bool {
        didSet {
            UserDefaults.standard.set(showLyricTimestamps, forKey: "showLyricTimestamps")
        }
    }
    
    init() {
        self.showLyricTimestamps = UserDefaults.standard.bool(forKey: "showLyricTimestamps")
    }
}
