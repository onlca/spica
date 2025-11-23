import SwiftUI
import AppKit
import MediaPlayer
import AVFoundation


@main
struct spicaApp: App {
    @StateObject private var viewModel = PlayerViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    // 应用即将退出时保存播放状态
                    viewModel.savePlaybackState()
                }
        }
    }
}
