import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // 通用设置视图
            VStack(alignment: .leading, spacing: 16) {
                Text("通用设置")
                    .font(.title2)
                    .padding(.bottom, 10)
                
                Text("Spica 音乐播放器")
                    .font(.headline)
                
                Text("使用纯 Swift 实现的音频标签解析")
                    .foregroundColor(.secondary)
                
                Divider()
                    .padding(.vertical, 10)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("支持格式:")
                        .font(.headline)
                    Text("• MP3 (ID3v2 标签)")
                    Text("• FLAC (Vorbis Comment)")
                }
                .foregroundColor(.secondary)
                
                Divider()
                    .padding(.vertical, 10)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("支持功能:")
                        .font(.headline)
                    Text("• 音频标签读取（标题、艺术家、专辑、曲目号）")
                    Text("• 内嵌歌词解析（支持 LRC 时间戳格式）")
                    Text("• 封面图片提取")
                }
                .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // 底部按钮区
            HStack {
                Spacer()
                Button("关闭") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 500, height: 400)
    }
}
