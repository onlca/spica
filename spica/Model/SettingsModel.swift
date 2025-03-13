import Foundation
import Combine

class SettingsModel: ObservableObject {
    @Published var pythonExecutablePath: String {
        didSet {
            UserDefaults.standard.set(pythonExecutablePath, forKey: "pythonExecutablePath")
        }
    }
    
    static let shared = SettingsModel()
    
    init() {
        self.pythonExecutablePath = UserDefaults.standard.string(forKey: "pythonExecutablePath") ?? "/usr/bin/python3"
    }
}
