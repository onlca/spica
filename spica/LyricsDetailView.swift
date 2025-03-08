// filepath: /Users/oplia/Documents/spica/spica/LyricsDetailView.swift
import SwiftUI

struct LyricsDetailView: View {
    @ObservedObject var viewModel: PlayerViewModel
    
    var body: some View {
        Group {
            if let song = viewModel.currentSong {
                if !song.lyrics.isEmpty {
                    LyricsView(lyrics: song.lyrics, viewModel: viewModel)
                        .padding()
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "text.quote")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("当前歌曲没有歌词")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("请选择歌曲查看歌词")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
