import SwiftUI

struct LyricsView: View {
    let lyrics: [String]
    @ObservedObject var viewModel: PlayerViewModel
    @State private var scrollPosition: Int? = nil
    
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
                        ForEach(Array(lyrics.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.body)
                                .foregroundColor(.primary)
                                .padding(.vertical, 3)
                                .padding(.horizontal, 5)
                                .id(index)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(isCurrentLyric(index: index) ? 
                                              Color.accentColor.opacity(0.2) : Color.clear)
                                )
                                .animation(.easeInOut, value: viewModel.progress)
                        }
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.progress) { _ in
                let currentIndex = getCurrentLyricIndex()
                if let index = currentIndex, scrollPosition != index {
                    scrollPosition = index
                    withAnimation {
                        proxy.scrollTo(index, anchor: .center)
                    }
                }
            }
        }
        .background(Color(.textBackgroundColor).opacity(0.2))
        .cornerRadius(8)
    }
    
    // 根据播放进度估计当前歌词位置
    private func getCurrentLyricIndex() -> Int? {
        guard !lyrics.isEmpty else { return nil }
        
        // 简单估算当前歌词位置 - 实际情况下可能需要更复杂的时间戳计算
        let position = Int(Double(lyrics.count) * viewModel.progress)
        let boundedPosition = max(0, min(position, lyrics.count - 1))
        
        return boundedPosition
    }
    
    // 检查是否是当前高亮显示的歌词行
    private func isCurrentLyric(index: Int) -> Bool {
        if let currentIndex = getCurrentLyricIndex() {
            return index == currentIndex
        }
        return false
    }
}

struct LyricsView_Previews: PreviewProvider {
    static var previews: some View {
        LyricsView(
            lyrics: [
                "这是第一行歌词",
                "这是第二行歌词",
                "这是第三行歌词",
                "这是第四行歌词"
            ],
            viewModel: PlayerViewModel()
        )
        .frame(width: 300, height: 200)
    }
}
