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
                    Text("Spica 音乐播放器")
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
            ScrollView {
                VStack(spacing: 24) {
                    // 应用信息卡片
                    VStack(alignment: .leading, spacing: 12) {
                        Label("关于", systemImage: "info.circle.fill")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            InfoRow(label: "版本", value: "0.1.26")
                            InfoRow(label: "开发", value: "纯 Swift 实现")
                            
                            Divider()
                                .padding(.vertical, 4)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("支持格式")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                HStack(spacing: 8) {
                                    FormatTag(text: "MP3")
                                    FormatTag(text: "FLAC")
                                }
                            }
                        }
                        .padding()
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(10)
                    }
                    
                    // 功能特性卡片
                    VStack(alignment: .leading, spacing: 12) {
                        Label("功能特性", systemImage: "star.fill")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            FeatureRow(icon: "music.note", text: "ID3v2 & Vorbis Comment 标签解析")
                            FeatureRow(icon: "text.alignleft", text: "LRC 格式歌词时间戳支持")
                            FeatureRow(icon: "photo", text: "内嵌封面图片提取")
                            FeatureRow(icon: "swift", text: "零外部依赖，原生性能")
                        }
                        .padding()
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(10)
                    }
                    
                    // 调试选项卡片
                    VStack(alignment: .leading, spacing: 12) {
                        Label("调试选项", systemImage: "wrench.and.screwdriver.fill")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                        
                        VStack(spacing: 0) {
                            Toggle(isOn: $settings.showLyricTimestamps) {
                                HStack {
                                    Image(systemName: "clock.fill")
                                        .foregroundColor(.accentColor)
                                        .frame(width: 20)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("显示歌词时间戳")
                                            .font(.body)
                                        Text("在歌词前显示时间信息（用于调试）")
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
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 20)
            }
            
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
        .frame(width: 600, height: 550)
    }
}

// MARK: - 辅助视图组件

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

struct FormatTag: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.2))
            .foregroundColor(.accentColor)
            .cornerRadius(4)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}
