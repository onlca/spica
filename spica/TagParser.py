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
            "artwork": None
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
                
            # 读取封面 - 处理大图像
            try:
                if audio.get("APIC:"):
                    image_data = audio["APIC:"].data
                    result["artwork"] = base64.b64encode(image_data).decode('utf-8')
                elif audio.get("APIC"):
                    image_data = audio["APIC"].data
                    result["artwork"] = base64.b64encode(image_data).decode('utf-8')
            except Exception as e:
                log(f"处理封面时出错: {e}")
        
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
                
            # 读取封面 - 限制大小
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
            except Exception as e:
                log(f"提取通用标签失败: {e}")
        
        # 输出JSON结果 - 分块处理大型输出
        log("生成JSON输出...")
        json_result = json.dumps(result)
        log(f"JSON输出长度: {len(json_result)} 字符")
        
        # 分段输出大型JSON，以避免缓冲区问题
        try:
            # 对于标题、艺术家和专辑信息单独输出
            metadata_only = {
                "title": result["title"],
                "artist": result["artist"],
                "album": result["album"]
            }
            
            # 输出元数据部分
            print(json.dumps(metadata_only))
            sys.stdout.flush()
            log("已输出基本元数据")
            
            # 如果有封面，再单独写入
            if result["artwork"]:
                # 写入到临时文件中
                temp_artwork_path = os.path.expanduser("~/Documents/spica_temp_artwork.json")
                with open(temp_artwork_path, "w") as f:
                    json.dump({"artwork": result["artwork"]}, f)
                
                log(f"封面数据已写入临时文件: {temp_artwork_path}")
            
        except Exception as e:
            log(f"输出JSON时出错: {e}")
            # 如果出错，尝试输出不含封面的JSON
            no_artwork = {k: v for k, v in result.items() if k != "artwork"}
            print(json.dumps(no_artwork))
            sys.stdout.flush()
        
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
