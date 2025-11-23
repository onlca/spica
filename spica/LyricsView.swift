import SwiftUI
import Combine

struct LyricsView: View {
    let lyrics: [LyricLine]
    @ObservedObject var viewModel: PlayerViewModel
    @ObservedObject private var settings = SettingsModel.shared
    @State private var currentIndex: Int = 0
    @State private var scrollProxy: ScrollViewProxy? = nil
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    if lyrics.isEmpty {
                        Text("暂无歌词")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 20)
                    } else {
                        // 顶部留白，确保首行歌词能居中显示
                        Color.clear.frame(height: 80)
                        
                        ForEach(lyrics.indices, id: \.self) { index in
                            HStack(spacing: 8) {
                                // 时间戳（调试模式）
                                if settings.showLyricTimestamps {
                                    Text(formatTimestamp(lyrics[index].timestamp))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary.opacity(0.6))
                                        .frame(width: 50, alignment: .trailing)
                                }
                                
                                // 歌词文本
                                Text(lyrics[index].text)
                                    .font(.system(size: 16))
                                    .foregroundColor(index == currentIndex ? .primary : .secondary)
                                    .fontWeight(index == currentIndex ? .bold : .regular)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 5)
                            .padding(.horizontal, 10)
                            .id(index)  // 设置ID用于滚动定位
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(index == currentIndex ? 
                                          Color.accentColor.opacity(0.2) : Color.clear)
                            )
                            .animation(.easeInOut(duration: 0.3), value: currentIndex)
                        }
                        
                        // 底部留白，确保末行歌词能居中显示
                        Color.clear.frame(height: 80)
                    }
                }
                .padding()
            }
            .onAppear {
                // 保存滚动代理以供后续使用
                self.scrollProxy = proxy
                // 初始更新歌词位置
                updateCurrentLyric()
            }
        }
        // 监听播放进度变化，更新当前歌词 - 使用新的onChange API
        .onChange(of: viewModel.progress) { oldValue, newValue in
            updateCurrentLyric()
        }
        // 当播放状态变化时，也更新歌词 - 使用新的onChange API
        .onChange(of: viewModel.isPlaying) { oldValue, newValue in
            updateCurrentLyric()
        }
        // 歌曲切换时重置状态 - 使用新的onChange API
        .onChange(of: viewModel.currentSong?.id) { oldValue, newValue in
            currentIndex = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                updateCurrentLyric()
            }
        }
    }
    
    private func updateCurrentLyric() {
        guard !lyrics.isEmpty else { return }
        
        // 当前播放时间（秒）
        guard let player = viewModel.audioPlayer, viewModel.isPlaying else { return }
        let currentTime = player.currentTime().seconds
        
        // 查找当前时间对应的歌词
        let nextIndex = findCurrentLyricIndex(at: currentTime)
        
        // 如果找到不同的索引，更新并滚动
        if nextIndex != currentIndex {
            withAnimation {
                currentIndex = nextIndex
                
                // 滚动到当前歌词
                scrollToCurrentLyric()
            }
        }
    }
    
    private func findCurrentLyricIndex(at time: Double) -> Int {
        // 查找最后一个时间戳小于等于当前时间的歌词
        var index = 0
        var foundTimestamped = false
        
        for i in 0..<lyrics.count {
            // 跳过无时间戳的歌词
            if lyrics[i].timestamp < 0 { continue }
            
            foundTimestamped = true
            if lyrics[i].timestamp <= time {
                index = i
            } else {
                break
            }
        }
        
        // 如果没有时间戳歌词，使用进度估算当前行
        if !foundTimestamped && lyrics.count > 1 {
            // 通过歌曲进度估算当前行
            let songProgress = viewModel.progress
            let estimatedIndex = Int(songProgress * Double(lyrics.count))
            return max(0, min(estimatedIndex, lyrics.count - 1))
        }
        
        return index
    }
    
    private func scrollToCurrentLyric() {
        // 滚动到当前高亮的歌词行
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.3)) {
                scrollProxy?.scrollTo(currentIndex, anchor: .center)
            }
        }
    }
    
    // 格式化时间戳显示
    private func formatTimestamp(_ timestamp: Double) -> String {
        if timestamp < 0 {
            return "--:--"
        }
        let minutes = Int(timestamp) / 60
        let seconds = Int(timestamp) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
