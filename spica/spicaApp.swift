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
        }
    }
}
