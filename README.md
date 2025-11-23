# spica MP

spica music player: 支持内嵌歌词显示的macOS音乐播放器

## 功能特性

- 🎵 支持 MP3/FLAC 格式音频文件播放
- 📝 内嵌歌词显示，支持 LRC 时间戳格式
- 🎨 专辑封面显示
- 🏷️ 音频标签读取（标题、艺术家、专辑、曲目号）
- ⚡ 纯 Swift 实现，无需外部依赖

## 技术实现

- 使用纯 Swift 实现音频标签解析
- 支持 MP3 文件的 ID3v2 标签解析
- 支持 FLAC 文件的 Vorbis Comment 和元数据块解析
- 参考 mutagen 库实现，完全使用 Swift 重写

## 支持格式

### MP3 (ID3v2)
- 标题、艺术家、专辑信息
- 曲目号
- USLT 歌词帧
- APIC 封面图片

### FLAC
- Vorbis Comment 标签
- Picture 元数据块
- 歌词字段

## Acknowledgements

开发过程中使用的工具：

- Github Copilot
- Claude 3.5 Sonnet
- Claude 3.7 Sonnet

参考项目：
- [Mutagen](https://github.com/quodlibet/mutagen) - Python 音频元数据库