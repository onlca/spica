#!/usr/bin/env python3
"""
Spica 音乐播放器清理工具

清理应用的配置和缓存数据
"""

import os
import shutil
from pathlib import Path


class SpicaCleaner:
    def __init__(self):
        self.home = Path.home()
        self.container_path = self.home / "Library/Containers/com.onlca.spica"
        self.cache_file = (
            self.container_path
            / "Data/Library/Application Support/com.spica.musicplayer/music_library_cache.json"
        )
        self.prefs_file = (
            self.container_path / "Data/Library/Preferences/com.onlca.spica.plist"
        )

    def check_exists(self):
        """检查应用数据是否存在"""
        if not self.container_path.exists():
            print("❌ 未找到 Spica 应用数据")
            return False
        return True

    def show_status(self):
        """显示当前状态"""
        print("\n📊 当前状态:")
        print("─" * 60)

        if self.container_path.exists():
            # 容器目录大小
            total_size = sum(
                f.stat().st_size for f in self.container_path.rglob("*") if f.is_file()
            )
            print(f"容器目录: {self.container_path}")
            print(f"总大小: {self._format_size(total_size)}")
        else:
            print("容器目录: 不存在")

        # 缓存文件
        if self.cache_file.exists():
            cache_size = self.cache_file.stat().st_size
            print(f"\n音乐库缓存: ✅ 存在 ({self._format_size(cache_size)})")
        else:
            print("\n音乐库缓存: ❌ 不存在")

        # 设置文件
        if self.prefs_file.exists():
            prefs_size = self.prefs_file.stat().st_size
            print(f"用户设置: ✅ 存在 ({self._format_size(prefs_size)})")
        else:
            print("用户设置: ❌ 不存在")

        print("─" * 60)

    def clean_cache(self):
        """清除音乐库缓存"""
        if self.cache_file.exists():
            try:
                size = self.cache_file.stat().st_size
                self.cache_file.unlink()
                print(f"✅ 已删除音乐库缓存 ({self._format_size(size)})")
                return True
            except Exception as e:
                print(f"❌ 删除缓存失败: {e}")
                return False
        else:
            print("ℹ️  音乐库缓存不存在")
            return False

    def clean_preferences(self):
        """清除用户设置"""
        if self.prefs_file.exists():
            try:
                size = self.prefs_file.stat().st_size
                self.prefs_file.unlink()
                print(f"✅ 已删除用户设置 ({self._format_size(size)})")
                return True
            except Exception as e:
                print(f"❌ 删除设置失败: {e}")
                return False
        else:
            print("ℹ️  用户设置不存在")
            return False

    def clean_all(self):
        """清除所有应用数据"""
        if self.container_path.exists():
            try:
                # 计算总大小
                total_size = sum(
                    f.stat().st_size
                    for f in self.container_path.rglob("*")
                    if f.is_file()
                )
                shutil.rmtree(self.container_path)
                print(f"✅ 已删除所有应用数据 ({self._format_size(total_size)})")
                print("   包括: 缓存、设置、日志、窗口状态等")
                return True
            except Exception as e:
                print(f"❌ 删除失败: {e}")
                return False
        else:
            print("ℹ️  应用数据不存在")
            return False

    @staticmethod
    def _format_size(size):
        """格式化文件大小"""
        for unit in ["B", "KB", "MB", "GB"]:
            if size < 1024.0:
                return f"{size:.2f} {unit}"
            size /= 1024.0
        return f"{size:.2f} TB"


def main():
    print("🎵 Spica 音乐播放器清理工具")
    print("=" * 60)

    cleaner = SpicaCleaner()

    if not cleaner.check_exists():
        return

    cleaner.show_status()

    print("\n请选择操作:")
    print("1. 清除音乐库缓存（保留设置）")
    print("2. 清除用户设置（保留缓存）")
    print("3. 清除所有应用数据")
    print("4. 仅查看状态")
    print("0. 退出")

    while True:
        choice = input("\n输入选项 [0-4]: ").strip()

        if choice == "0":
            print("👋 再见！")
            break
        elif choice == "1":
            print("\n🗑️  清除音乐库缓存...")
            cleaner.clean_cache()
            print("\n✨ 完成！下次启动时会重新扫描音乐文件夹")
            break
        elif choice == "2":
            print("\n🗑️  清除用户设置...")
            cleaner.clean_preferences()
            print("\n✨ 完成！所有设置将恢复为默认值")
            break
        elif choice == "3":
            confirm = input("\n⚠️  将删除所有应用数据，确定吗？[y/N]: ").strip().lower()
            if confirm == "y":
                print("\n🗑️  清除所有应用数据...")
                cleaner.clean_all()
                print("\n✨ 完成！应用将完全重置")
                break
            else:
                print("❌ 已取消")
                break
        elif choice == "4":
            cleaner.show_status()
            break
        else:
            print("❌ 无效选项，请重新输入")


if __name__ == "__main__":
    main()
