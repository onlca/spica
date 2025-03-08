#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import os
import json
import base64
from pathlib import Path
from datetime import datetime

def parse_lyrics_with_timestamps(lyrics_text):
    """解析带时间标签的歌词"""
    lines = lyrics_text.split('\n')
    parsed_lyrics = []
    
    # 常见时间标签正则匹配
    import re
    # [00:00.00] 或 [00:00:00] 格式
    time_pattern = re.compile(r'\[(\d+):(\d+)(?:\.(\d+)|:(\d+))?\]')
    
    for line in lines:
        line = line.strip()
        if not line:
            continue
        
        match = time_pattern.search(line)
        if match:
            # 提取时间
            minutes = int(match.group(1))
            seconds = int(match.group(2))
            
            # 转换为总秒数
            timestamp = minutes * 60 + seconds
            
            # 提取歌词内容
            text = line[match.end():].strip()
            
            parsed_lyrics.append({"time": timestamp, "text": text})
        else:
            # 没有时间标签，仍然添加内容
            parsed_lyrics.append({"time": -1, "text": line})
    
    return parsed_lyrics

def get_tags(file_path):
    """解析音频文件标签"""
    # 检查文件是否存在
    if not os.path.exists(file_path):
        print(json.dumps({"error": f"文件不存在: {file_path}"}))
        return
    
    try:
        from mutagen import File
        from mutagen.id3 import ID3
        from mutagen.flac import FLAC
        from mutagen.mp3 import MP3
    except ImportError:
        print(json.dumps({"error": "未安装 mutagen 库"}))
        sys.exit(1)
    
    try:
        # 默认结果
        result = {
            "title": Path(file_path).stem,
            "artist": "未知艺术家",
            "album": "未知专辑",
            "artwork": None,
            "lyrics": []
        }
        
        # 尝试加载文件
        file_ext = Path(file_path).suffix.lower()
        
        # 先检查是否为MP3文件
        if file_ext == '.mp3':
            audio = MP3(file_path)
            if audio.tags:
                id3 = audio.tags
                all_keys = list(id3.keys())
                
                # 提取标题、艺术家和专辑
                if 'TIT2' in id3:
                    result["title"] = str(id3['TIT2'])
                if 'TPE1' in id3:
                    result["artist"] = str(id3['TPE1'])
                if 'TALB' in id3:
                    result["album"] = str(id3['TALB'])
                
                # 提取歌词
                lyrics_text = None
                
                # 先尝试标准USLT标签
                for key in all_keys:
                    if key.startswith('USLT'):
                        uslt_frame = id3[key]
                        lyrics_text = str(uslt_frame)
                        break
                
                # 再尝试TXXX自定义标签中的歌词字段
                if not lyrics_text:
                    for key in all_keys:
                        if key.startswith('TXXX'):
                            txxx_frame = id3[key]
                            if 'lyrics' in str(txxx_frame.desc).lower():
                                lyrics_text = str(txxx_frame)
                                break
                
                # 处理歌词
                if lyrics_text:
                    result["lyrics"] = parse_lyrics_with_timestamps(lyrics_text)
                    
                # 提取封面
                for key in all_keys:
                    if key.startswith('APIC'):
                        apic_frame = id3[key]
                        image_data = apic_frame.data
                        result["artwork"] = base64.b64encode(image_data).decode('utf-8')
                        break
                        
        # 如果不是MP3或MP3处理失败，尝试通用方式
        else:
            audio = File(file_path)
            
            # 如果无法加载文件
            if not audio:
                print(json.dumps(result))
                sys.stdout.flush()
                return
            
            # 处理FLAC文件
            if isinstance(audio, FLAC):
                # 标准标签
                if "TITLE" in audio:
                    result["title"] = audio["TITLE"][0]
                if "ARTIST" in audio:
                    result["artist"] = audio["ARTIST"][0]
                if "ALBUM" in audio:
                    result["album"] = audio["ALBUM"][0]
                    
                # 读取歌词 (LYRICS标签)
                if "LYRICS" in audio:
                    lyrics_text = audio["LYRICS"][0]
                    result["lyrics"] = parse_lyrics_with_timestamps(lyrics_text)
                
                # 读取封面
                try:
                    if hasattr(audio, "pictures") and audio.pictures:
                        image_data = audio.pictures[0].data
                        result["artwork"] = base64.b64encode(image_data).decode('utf-8')
                except Exception:
                    pass
            
            # 通用方法处理其他格式
            else:
                tags = audio
                
                # 尝试获取更多的标签信息
                if hasattr(tags, "tags") and tags.tags:
                    tags = tags.tags
                    
                # 提取常见标签
                try:
                    if "title" in tags:
                        result["title"] = str(tags["title"][0])
                    if "artist" in tags:
                        result["artist"] = str(tags["artist"][0])
                    if "album" in tags:
                        result["album"] = str(tags["album"][0])
                    if "lyrics" in tags:
                        lyrics_text = str(tags["lyrics"][0])
                        result["lyrics"] = parse_lyrics_with_timestamps(lyrics_text)
                except Exception:
                    pass
        
        # 拆分结果，先输出不包含封面的部分
        metadata_result = {
            "title": result["title"],
            "artist": result["artist"],
            "album": result["album"],
            "lyrics": result["lyrics"]
        }
        
        print(json.dumps(metadata_result))
        sys.stdout.flush()
        
        # 如果有封面，处理封面数据
        if result["artwork"]:
            # 写入到临时文件中
            temp_artwork_path = os.path.expanduser("~/Documents/spica_temp_artwork.json")
            with open(temp_artwork_path, "w") as f:
                json.dump({"artwork": result["artwork"]}, f)
        
    except Exception as e:
        error_result = {
            "error": str(e),
            "title": Path(file_path).stem,
            "artist": "未知艺术家",
            "album": "未知专辑",
            "lyrics": []
        }
        print(json.dumps(error_result))
        sys.stdout.flush()

# 主入口点
if __name__ == "__main__":
    if len(sys.argv) <= 1:
        print(json.dumps({"error": "未提供文件路径"}))
    else:
        file_path = sys.argv[1]
        get_tags(file_path)
