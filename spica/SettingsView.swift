import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = SettingsModel.shared
    
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
                // 歌词显示选项
                VStack(alignment: .leading, spacing: 12) {
                    Label("歌词显示", systemImage: "text.alignleft")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                    
                    VStack(spacing: 0) {
                        Toggle(isOn: $settings.showLyricTimestamps) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.accentColor)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("显示时间戳")
                                        .font(.body)
                                    Text("在歌词前显示时间信息")
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
        .frame(width: 500, height: 300)
    }
}
