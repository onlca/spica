import SwiftUI

struct AlbumArtView: View {
    let song: SecureSong
    
    var body: some View {
        VStack(spacing: 12) {
            Group {
                if let artwork = song.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(12)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.thinMaterial)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                        )
                }
            }
            .frame(maxWidth: 240, maxHeight: 240)
            .shadow(radius: 4)
            
            VStack(spacing: 4) {
                Text(song.title)
                    .font(.title2.bold())
                    .lineLimit(1)
                
                Text(song.artist)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                Text(song.album)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// 预览提供者
struct AlbumArtView_Previews: PreviewProvider {
    static var previews: some View {
        AlbumArtView(song: SecureSong(
            title: "预览歌曲",
            artist: "预览艺术家",
            album: "预览专辑",
            duration: 180,
            fileURL: URL(string: "file://example")!,
            artwork: nil
        ))
        .padding()
        .frame(width: 300)
    }
}
