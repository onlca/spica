#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "pillow>=10.0.0",
# ]
# ///
"""
macOS 应用图标生成器
从单张图片生成 macOS 所需的所有尺寸图标，并直接替换到 Xcode 项目中
"""

import sys
from pathlib import Path
from PIL import Image

# 定义所需的图标尺寸
ICON_SIZES = {
    # macOS 图标尺寸
    "icon-16.png": 16,
    "icon-16@2x.png": 32,  # 32 (16@2x)
    "icon-32.png": 32,
    "icon-32@2x.png": 64,
    "icon-128.png": 128,
    "icon-128@2x.png": 256,  # 256 (128@2x)
    "icon-256.png": 256,
    "icon-256@2x.png": 512,  # 512 (256@2x)
    "icon-512.png": 512,
    "icon-512@2x.png": 1024,
    # iOS 和通用图标
    "icon-1024.png": 1024,
}

# 额外的命名变体（用于 Contents.json 中的不同引用）
EXTRA_NAMES = {
    32: ["icon-32 1.png"],
    256: ["icon-256 1.png"],
    512: ["icon-512 1.png"],
    1024: ["icon-512@2x 1.png", "icon-512@2x 2.png", "icon-512@2x 3.png"],
}


def resize_image(img: Image.Image, size: int) -> Image.Image:
    """
    调整图片大小，保持高质量
    使用 LANCZOS 重采样算法获得最佳质量
    """
    return img.resize((size, size), Image.Resampling.LANCZOS)


def generate_icons(input_path: str):
    """
    从输入图片生成所有需要的图标尺寸
    """
    input_file = Path(input_path)
    
    if not input_file.exists():
        print(f"❌ 错误: 文件不存在: {input_path}")
        sys.exit(1)
    
    print(f"📖 读取图片: {input_file.name}")
    
    try:
        # 打开图片
        img = Image.open(input_file)
        
        # 转换为 RGBA 模式（支持透明度）
        if img.mode != 'RGBA':
            print(f"   转换图片模式: {img.mode} -> RGBA")
            img = img.convert('RGBA')
        
        # 确保图片是正方形
        width, height = img.size
        if width != height:
            print(f"   图片不是正方形 ({width}x{height})，裁剪为正方形...")
            min_size = min(width, height)
            left = (width - min_size) // 2
            top = (height - min_size) // 2
            right = left + min_size
            bottom = top + min_size
            img = img.crop((left, top, right, bottom))
            print(f"   裁剪后尺寸: {min_size}x{min_size}")
        
        print(f"✅ 原始图片尺寸: {img.size[0]}x{img.size[1]}")
        
    except Exception as e:
        print(f"❌ 错误: 无法打开图片: {e}")
        sys.exit(1)
    
    # 获取项目目录
    project_dir = Path(__file__).parent
    output_dir = project_dir / "spica" / "Assets.xcassets" / "AppIcon.appiconset"
    
    if not output_dir.exists():
        print(f"❌ 错误: 输出目录不存在: {output_dir}")
        sys.exit(1)
    
    print(f"\n📁 输出目录: {output_dir}")
    print(f"\n🔨 开始生成图标...")
    
    # 生成所有尺寸的图标
    generated_sizes = set()
    
    for filename, size in ICON_SIZES.items():
        try:
            # 调整图片大小
            resized_img = resize_image(img, size)
            
            # 保存图片
            output_path = output_dir / filename
            resized_img.save(output_path, 'PNG', optimize=True)
            
            generated_sizes.add(size)
            print(f"   ✓ {filename:<20} ({size}x{size})")
            
        except Exception as e:
            print(f"   ✗ {filename:<20} 失败: {e}")
    
    # 生成额外的命名变体
    print(f"\n📋 生成命名变体...")
    for size, names in EXTRA_NAMES.items():
        if size in generated_sizes:
            resized_img = resize_image(img, size)
            for name in names:
                try:
                    output_path = output_dir / name
                    resized_img.save(output_path, 'PNG', optimize=True)
                    print(f"   ✓ {name:<20} ({size}x{size})")
                except Exception as e:
                    print(f"   ✗ {name:<20} 失败: {e}")
    
    print(f"\n✨ 完成! 已生成 {len(ICON_SIZES) + sum(len(names) for names in EXTRA_NAMES.values())} 个图标文件")
    print(f"📍 位置: {output_dir}")
    
    # 清理图标缓存
    print(f"\n🧹 清理 macOS 图标缓存...")
    import subprocess
    try:
        # 清理图标缓存
        subprocess.run(["sudo", "rm", "-rf", "/Library/Caches/com.apple.iconservices.store"], check=False)
        subprocess.run(["killall", "Dock"], check=False)
        subprocess.run(["killall", "Finder"], check=False)
        print(f"   ✓ 已清理图标缓存并重启 Dock 和 Finder")
        print(f"\n💡 提示: 如果图标仍未更新，请在 Xcode 中 Clean Build Folder (Shift+Cmd+K) 并重新编译")
    except Exception as e:
        print(f"   ⚠️  无法自动清理缓存: {e}")
        print(f"\n💡 请手动执行以下命令更新系统图标:")
        print(f"   sudo rm -rf /Library/Caches/com.apple.iconservices.store")
        print(f"   killall Dock")
        print(f"   killall Finder")


def main():
    if len(sys.argv) != 2:
        print("用法: uv run generate_icons.py <图片路径>")
        print("\n示例:")
        print("  uv run generate_icons.py icon.png")
        print("  uv run generate_icons.py ~/Downloads/app-icon.jpg")
        sys.exit(1)
    
    input_path = sys.argv[1]
    generate_icons(input_path)


if __name__ == "__main__":
    main()
