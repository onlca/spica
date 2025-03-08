#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import os
import json
import base64
import traceback
from pathlib import Path
from datetime import datetime

# 设置日志文件
LOG_FILE = os.path.expanduser("~/Documents/spica_debug.log")

def log(message):
    """将消息写入日志文件"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(f"[{timestamp}] {message}\n")

# 记录脚本启动
log("TagParser.py 脚本启动")
log(f"Python版本: {sys.version}")
log(f"工作目录: {os.getcwd()}")
log(f"脚本参数: {sys.argv}")

# 检查 mutagen 库
try:
    from mutagen import File
    from mutagen.id3 import ID3
    from mutagen.flac import FLAC
    log("Mutagen库导入成功")
except ImportError as e:
    log(f"Mutagen库导入失败: {e}")
    print(json.dumps({"error": "未安装 mutagen 库"}))
    sys.exit(1)

def parse_lyrics_with_timestamps(lyrics_text):
    """解析带时间标签的歌词"""
    lines = lyrics_text.split('\n')
    parsed_lyrics = []
    
    # 常见时间标签正则匹配
    import re
    # [00:00.00] 或 [00:00:00] 格式
    time_pattern = re.compile(r'\[(\d+):(\d+)(?:\.(\d+)|:(\d+))?\]')
    
    log(f"开始解析带时间标签的歌词，共 {len(lines)} 行")
    
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
            log(f"解析歌词行: {timestamp}秒 - {text}")
        else:
            # 没有时间标签，仍然添加内容
            parsed_lyrics.append({"time": -1, "text": line})
            log(f"添加无时间标签歌词: {line}")
    
    return parsed_lyrics

def get_tags(file_path):
    """解析音频文件标签"""
    log(f"正在处理文件: {file_path}")
    
    # 检查文件是否存在
    if not os.path.exists(file_path):
        log(f"文件不存在: {file_path}")
        print(json.dumps({"error": f"文件不存在: {file_path}"}))
        return
    
    # 获取基本文件信息
    file_name = Path(file_path).stem
    file_size = os.path.getsize(file_path)
    log(f"文件名: {file_name}, 大小: {file_size} 字节")
    
    try:
        # 加载文件
        log("尝试加载音频文件...")
        audio = File(file_path)
        
        # 默认结果
        result = {
            "title": file_name,
            "artist": "未知艺术家",
            "album": "未知专辑",
            "artwork": None,
            "lyrics": []  # 添加歌词字段，使用数组保存带时间戳的歌词
        }
        
        # 如果无法加载文件
        if not audio:
            log("无法识别的音频格式")
            print(json.dumps(result))
            sys.stdout.flush()
            return
        
        # 记录音频类型
        log(f"识别到的音频类型: {type(audio).__name__}")
        
        # 处理MP3文件
        if isinstance(audio, ID3) or type(audio).__name__ == 'ID3':
            log("正在处理MP3文件...")
            
            # 列出所有可用标签
            all_keys = list(audio.keys()) if hasattr(audio, "keys") else []
            log(f"可用ID3标签: {all_keys}")
            
            # 读取标准标签
            if audio.get("TIT2"):
                result["title"] = str(audio["TIT2"])
                log(f"提取到标题: {result['title']}")
            if audio.get("TPE1"):
                result["artist"] = str(audio["TPE1"])
                log(f"提取到艺术家: {result['artist']}")
            if audio.get("TALB"):
                result["album"] = str(audio["TALB"])
                log(f"提取到专辑: {result['album']}")
                
            # 读取封面
            try:
                if audio.get("APIC:"):
                    image_data = audio["APIC:"].data
                    result["artwork"] = base64.b64encode(image_data).decode('utf-8')
                elif audio.get("APIC"):
                    image_data = audio["APIC"].data
                    result["artwork"] = base64.b64encode(image_data).decode('utf-8')
            except Exception as e:
                log(f"处理封面时出错: {e}")
            
            # 读取歌词 (USLT标签)
            try:
                for key in audio.keys():
                    if key.startswith("USLT"):
                        log(f"找到歌词标签: {key}")
                        lyrics_text = str(audio[key])
                        
                        # 尝试解析时间标签
                        result["lyrics"] = parse_lyrics_with_timestamps(lyrics_text)
                        log(f"解析到带时间标签歌词: {len(result['lyrics'])} 行")
                        break
            except Exception as e:
                log(f"处理歌词时出错: {e}")
        
        # 处理FLAC文件
        elif isinstance(audio, FLAC):
            log("正在处理FLAC文件...")
            
            # 列出所有可用标签
            all_keys = list(audio.keys()) if hasattr(audio, "keys") else []
            log(f"可用FLAC标签: {all_keys}")
            
            if "TITLE" in audio:
                result["title"] = audio["TITLE"][0]
                log(f"提取到标题: {result['title']}")
            if "ARTIST" in audio:
                result["artist"] = audio["ARTIST"][0]
                log(f"提取到艺术家: {result['artist']}")
            if "ALBUM" in audio:
                result["album"] = audio["ALBUM"][0]
                log(f"提取到专辑: {result['album']}")
                
            # 读取歌词 (LYRICS标签)
            if "LYRICS" in audio:
                lyrics_text = audio["LYRICS"][0]
                result["lyrics"] = parse_lyrics_with_timestamps(lyrics_text)
                log(f"解析到带时间标签歌词: {len(result['lyrics'])} 行")
            
            # 读取封面
            try:
                if hasattr(audio, "pictures") and audio.pictures:
                    log(f"FLAC图片数量: {len(audio.pictures)}")
                    image_data = audio.pictures[0].data
                    result["artwork"] = base64.b64encode(image_data).decode('utf-8')
            except Exception as e:
                log(f"处理FLAC封面时出错: {e}")
        
        # 通用方法处理其他格式
        else:
            log(f"使用通用方法处理格式: {type(audio).__name__}")
            tags = audio
            
            # 尝试获取更多的标签信息
            if hasattr(tags, "tags") and tags.tags:
                tags = tags.tags
                log("使用tags属性获取标签...")
                
            # 尝试列出所有标签
            try:
                if hasattr(tags, "keys"):
                    all_keys = list(tags.keys())
                    log(f"可用标签: {all_keys}")
            except Exception as e:
                log(f"获取标签列表失败: {e}")
                
            # 提取常见标签
            try:
                if "title" in tags:
                    result["title"] = str(tags["title"][0])
                    log(f"提取到标题: {result['title']}")
                if "artist" in tags:
                    result["artist"] = str(tags["artist"][0])
                    log(f"提取到艺术家: {result['artist']}")
                if "album" in tags:
                    result["album"] = str(tags["album"][0])
                    log(f"提取到专辑: {result['album']}")
                if "lyrics" in tags:
                    lyrics_text = str(tags["lyrics"][0])
                    lyrics_lines = lyrics_text.split('\n')
                    result["lyrics"] = lyrics_lines
                    log(f"提取到歌词行数: {len(lyrics_lines)}")
            except Exception as e:
                log(f"提取通用标签失败: {e}")
        
        # 输出结果 - 不包括大图片数据
        log("生成JSON输出...")
        
        # 拆分结果，先输出不包含封面的部分
        metadata_result = {
            "title": result["title"],
            "artist": result["artist"],
            "album": result["album"],
            "lyrics": result["lyrics"]
        }
        
        print(json.dumps(metadata_result))
        sys.stdout.flush()
        log("已输出基本元数据")
        
        # 如果有封面，处理封面数据
        if result["artwork"]:
            # 写入到临时文件中
            temp_artwork_path = os.path.expanduser("~/Documents/spica_temp_artwork.json")
            with open(temp_artwork_path, "w") as f:
                json.dump({"artwork": result["artwork"]}, f)
            
            log(f"封面数据已写入临时文件: {temp_artwork_path}")
        
    except Exception as e:
        # 记录详细错误
        error_msg = f"处理文件时发生错误: {str(e)}"
        stack_trace = traceback.format_exc()
        log(error_msg)
        log(stack_trace)
        
        # 输出错误JSON
        error_result = {
            "error": error_msg,
            "title": file_name,
            "artist": "未知艺术家",
            "album": "未知专辑",
            "lyrics": []
        }
        print(json.dumps(error_result))
        sys.stdout.flush()

# 主入口点
if __name__ == "__main__":
    log("进入主函数")
    
    if len(sys.argv) <= 1:
        log("未提供文件路径参数")
        print(json.dumps({"error": "未提供文件路径"}))
    else:
        file_path = sys.argv[1]
        log(f"准备处理文件: {file_path}")
        get_tags(file_path)
    
    log("TagParser.py 脚本执行完毕\n" + "-"*50)
