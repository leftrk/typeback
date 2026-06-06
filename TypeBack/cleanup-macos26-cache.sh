#!/bin/bash
# macOS 26 (Tahoe) 菜单栏图标缓存清理脚本
#
# 问题：v1.1.0 之前版本的 TypeBack 在 macOS 26 上菜单栏图标不显示。
# 原因：LSMinimumSystemVersion=14.0 导致 macOS 26 将状态项放置到屏幕外。
#
# 此脚本清理系统缓存，让 v1.1.1 正常显示菜单栏图标。
#
# 使用方法：
#   chmod +x cleanup-macos26-cache.sh
#   ./cleanup-macos26-cache.sh

set -e

echo "=== TypeBack macOS 26 缓存清理 ==="

# 1. 停止 TypeBack
echo "停止 TypeBack..."
killall TypeBack 2>/dev/null || true

# 2. 停止 ControlCenter
echo "重启 ControlCenter..."
killall ControlCenter 2>/dev/null || true

# 3. 清理 LaunchServices 注册
echo "清理 LaunchServices 注册..."
lsregister="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
$lsregister -u /Applications/TypeBack.app 2>/dev/null || true

# 4. 清理 displayablemenuextras plist（菜单栏状态缓存）
echo "清理菜单栏状态缓存..."
rm -f ~/Library/Preferences/ByHost/com.apple.controlcenter.displayablemenuextras*.plist 2>/dev/null || true
rm -f ~/Library/Preferences/com.apple.controlcenter.plist 2>/dev/null || true
rm -f ~/Library/Preferences/ByHost/com.apple.controlcenter*.plist 2>/dev/null || true

# 5. 清理 DuetExpertCenter 中的 app 记录
echo "清理 DuetExpertCenter 数据库..."
sqlite3 ~/Library/DuetExpertCenter/_ATXDataStore.db "DELETE FROM alogBundleId WHERE bundleId LIKE '%typeback%';" 2>/dev/null || true

# 6. 清理旧 defaults
echo "清理旧配置..."
defaults delete com.huaguan.typeback 2>/dev/null || true
defaults delete com.huaguan.typeback.app 2>/dev/null || true

# 7. 重新注册新版本
echo "重新注册 TypeBack..."
$lsregister -f /Applications/TypeBack.app 2>/dev/null || true

# 8. 等待系统稳定
echo "等待系统重启服务..."
sleep 5

echo ""
echo "✅ 清理完成！"
echo ""
echo "下一步："
echo "  1. 通过 Homebrew 安装新版本: brew reinstall --cask typeback"
echo "  2. 或手动安装 v1.1.1 DMG"
echo "  3. 启动 TypeBack，菜单栏图标应正常显示"
