//
//  spicaApp.swift
//  spica
//
//  Created by oplia on 2025/3/8.
//

import SwiftUI
import AppKit
import MediaPlayer
import AVFoundation

// 创建AppDelegate处理媒体键事件
class AppDelegate: NSObject, NSApplicationDelegate {
    // 使用普通引用
    var viewModel: PlayerViewModel!
    
    // 设置事件监听
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 配置应用程序作为媒体处理程序
        configureAsMediaApp()
        
        // 设置媒体键监听
        setupMediaKeyMonitoring()
    }
    
    // 配置应用程序作为媒体处理程序
    private func configureAsMediaApp() {
        // 在macOS中，通过更新NowPlayingInfoCenter来标记应用为媒体处理程序
        let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
        nowPlayingInfoCenter.nowPlayingInfo = [MPNowPlayingInfoPropertyIsLiveStream: false]
        
        // 确保远程命令中心已配置
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // 确保播放命令已启用
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.isEnabled = true
    }
    
    // 设置媒体键监听
    private func setupMediaKeyMonitoring() {
        // 使用NSEvent来监听媒体键事件 - 本地监控（应用程序处于前台）
        NSEvent.addLocalMonitorForEvents(matching: [.systemDefined]) { [weak self] event in
            guard let self = self else { return event }
            return self.handleMediaKeyEvent(event)
        }
        
        // 全局监控（即使应用程序不在前台）- 注意：Apple对媒体键的全局监听有限制
        NSEvent.addGlobalMonitorForEvents(matching: [.systemDefined]) { [weak self] event in
            // 对于全局监视器，只处理事件但不阻止传播
            _ = self?.handleMediaKeyEvent(event, isGlobal: true)
        }
    }
    
    // 处理媒体键事件，返回nil表示事件已被处理，不应继续传播
    private func handleMediaKeyEvent(_ event: NSEvent, isGlobal: Bool = false) -> NSEvent? {
        // 检查是否是媒体键事件：系统定义的事件，子类型为8
        guard event.type == .systemDefined, event.subtype.rawValue == 8 else {
            return event
        }
        
        // 媒体键事件处理
        let data1 = event.data1
        let keyCode = (data1 & 0xFFFF0000) >> 16
        let keyFlags = data1 & 0x0000FFFF
        let keyState = (keyFlags & 0xFF00) >> 8
        let keyIsPressed = keyState == 0xA // 0xA = 按下, 0xB = 释放
        
        // 只处理按下状态
        guard keyIsPressed else { return event }
        
        guard let viewModel = self.viewModel else { return event }
        
        // 识别键码并执行相应操作
        switch Int(keyCode) {
        case Int(NX_KEYTYPE_PLAY):  // 播放/暂停
            if let currentSong = viewModel.currentSong {
                if viewModel.isPlaying {
                    viewModel.pause()
                } else {
                    viewModel.play(song: currentSong)
                }
                return isGlobal ? event : nil
            }
            
        case Int(NX_KEYTYPE_FAST):  // 下一曲
            if let currentSong = viewModel.currentSong,
               let currentIndex = viewModel.playlist.firstIndex(where: { $0.id == currentSong.id }),
               !viewModel.playlist.isEmpty {
                let nextIndex = (currentIndex + 1) % viewModel.playlist.count
                viewModel.play(song: viewModel.playlist[nextIndex])
                return isGlobal ? event : nil
            }
            
        case Int(NX_KEYTYPE_REWIND):  // 上一曲
            if let currentSong = viewModel.currentSong,
               let currentIndex = viewModel.playlist.firstIndex(where: { $0.id == currentSong.id }),
               !viewModel.playlist.isEmpty {
                let previousIndex = (currentIndex - 1 + viewModel.playlist.count) % viewModel.playlist.count
                viewModel.play(song: viewModel.playlist[previousIndex])
                return isGlobal ? event : nil
            }
            
        default:
            break
        }
        
        return event
    }
    
    // 应用程序变为活动状态时
    func applicationDidBecomeActive(_ notification: Notification) {
        viewModel.updateNowPlayingInfo()
    }
    
    // 应用程序即将退出
    func applicationWillTerminate(_ notification: Notification) {
        viewModel.releaseSecurityScopedResources()
    }
}

@main
struct spicaApp: App {
    // 将@StateObject移到主App结构中
    @StateObject private var viewModel = PlayerViewModel()
    
    // 注册AppDelegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // 在初始化方法中为AppDelegate提供ViewModel引用
        appDelegate.viewModel = viewModel
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}
