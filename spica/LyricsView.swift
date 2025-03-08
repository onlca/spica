import SwiftUI
import Combine

struct LyricsView: View {
    let lyrics: [LyricLine]
    @ObservedObject var viewModel: PlayerViewModel
    @State private var currentIndex: Int = 0
    @State private var scrollProxy: ScrollViewProxy? = nil
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if lyrics.isEmpty {
                        Text("暂无歌词")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 20)
                    } else {
                        ForEach(lyrics.indices, id: \.self) { index in
                            Text(lyrics[index].text)
                                .font(.system(size: 16))
                                .foregroundColor(index == currentIndex ? .primary : .secondary)
                                .fontWeight(index == currentIndex ? .bold : .regular)
                                .padding(.vertical, 5)
                                .padding(.horizontal, 10)
                                .id(index)  // 设置ID用于滚动定位
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(index == currentIndex ? 
                                              Color.accentColor.opacity(0.2) : Color.clear)
                                )
                                .animation(.easeInOut(duration: 0.3), value: currentIndex)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding()
            }
            .onAppear {
                // 保存滚动代理以供后续使用
                self.scrollProxy = proxy
            }
        }
        .background(Color(.textBackgroundColor).opacity(0.2))
        .cornerRadius(8)
        // 监听播放进度变化，更新当前歌词
        .onChange(of: viewModel.progress) { _ in
            updateCurrentLyric()
        }
        // 当播放状态变化时，也更新歌词
        .onChange(of: viewModel.isPlaying) { _ in
            updateCurrentLyric()
        }
    }
    
    private func updateCurrentLyric() {
        guard !lyrics.isEmpty else { return }
        
        // 当前播放时间（秒）
        guard let player = viewModel.audioPlayer else { return }
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
        
        for i in 0..<lyrics.count {
            // 跳过无时间戳的歌词
            if lyrics[i].timestamp < 0 { continue }
            
            if lyrics[i].timestamp <= time {
                index = i
            } else {
                break
            }
        }
        
        return index
    }
    
    private func scrollToCurrentLyric() {
        // 滚动到当前高亮的歌词行
        scrollProxy?.scrollTo(currentIndex, anchor: .center)
    }
}

struct LyricsView_Previews: PreviewProvider {
    static var previews: some View {
        let vm = PlayerViewModel()
        
        // 创建一些测试数据
        let sampleLyrics = [
            LyricLine(timestamp: 0.0, text: "这是第一行歌词"),
            LyricLine(timestamp: 5.0, text: "这是第二行歌词"),
            LyricLine(timestamp: 10.0, text: "这是第三行歌词"),
            LyricLine(timestamp: 15.0, text: "这是第四行歌词")
        ]
        
        return LyricsView(lyrics: sampleLyrics, viewModel: vm)
            .frame(width: 300, height: 200)
    }
}
