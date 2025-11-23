import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = SettingsModel.shared
    @EnvironmentObject private var viewModel: PlayerViewModel
    @State private var showingFolderPicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 头部
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("设置")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("spica 音乐播放器")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 30)
            .padding(.top, 30)
            .padding(.bottom, 20)
            
            Divider()
            
            // 设置内容区域
            VStack(spacing: 24) {
                // 音乐库设置
                VStack(alignment: .leading, spacing: 12) {
                    Label("音乐库", systemImage: "music.note.list")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                    
                    VStack(spacing: 0) {
                        // 文件夹路径显示
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.accentColor)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("音乐文件夹")
                                    .font(.body)
                                if let folderURL = settings.musicFolderURL {
                                    Text(folderURL.path)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                } else {
                                    Text("未选择")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Button("选择...") {
                                selectMusicFolder()
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                        
                        if settings.musicFolderURL != nil {
                            Divider()
                                .padding(.horizontal)
                            
                            // 刷新按钮
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(.accentColor)
                                    .frame(width: 20)
                                Text("刷新音乐库")
                                    .font(.body)
                                Spacer()
                                if viewModel.isLoadingLibrary {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Button("刷新") {
                                        Task {
                                            await viewModel.refreshMusicLibrary()
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            .padding()
                            
                            Divider()
                                .padding(.horizontal)
                            
                            // 清除缓存按钮
                            HStack {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("清除缓存")
                                        .font(.body)
                                    Text("删除已保存的音乐库缓存")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("清除") {
                                    MusicLibraryManager.shared.clearCache()
                                    // 显示缓存路径
                                    print("缓存已清除: \(MusicLibraryManager.shared.getCachePath())")
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            }
                            .padding()
                        }
                    }
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(10)
                }
                
                // 显示选项
                VStack(alignment: .leading, spacing: 12) {
                    Label("显示选项", systemImage: "eye")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                    
                    VStack(spacing: 0) {
                        // 显示时间戳
                        Toggle(isOn: $settings.showLyricTimestamps) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.accentColor)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("显示歌词时间戳")
                                        .font(.body)
                                    Text("在歌词前显示时间信息")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .toggleStyle(.switch)
                        .padding()
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // 显示状态栏
                        Toggle(isOn: $settings.showStatusBar) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.accentColor)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("显示底部状态栏")
                                        .font(.body)
                                    Text("显示音频信息和播放统计")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .toggleStyle(.switch)
                        .padding()
                    }
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(10)
                }
                
                Spacer()
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 20)
            
            Divider()
            
            // 底部按钮区
            HStack {
                Spacer()
                Button("完成") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 16)
            .background(Color(.controlBackgroundColor).opacity(0.5))
        }
        .frame(width: 550, height: 500)
    }
    
    // 选择音乐文件夹
    private func selectMusicFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "选择"
        panel.message = "选择包含音乐文件的文件夹"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                settings.musicFolderURL = url
                // 加载音乐库
                Task {
                    await viewModel.loadMusicLibrary()
                }
            }
        }
    }
}
