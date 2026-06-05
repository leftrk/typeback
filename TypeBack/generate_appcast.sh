#!/bin/bash
# TypeBack appcast 生成脚本

set -e

cd "$(dirname "$0")"

APP_NAME="TypeBack"
APP_VERSION="1.1.0"
DMG_PATH="${1:-dist/${APP_NAME}.dmg}"

if [ ! -f "$DMG_PATH" ]; then
    echo "错误: DMG 文件不存在: $DMG_PATH"
    exit 1
fi

SPARKLE_BIN=".build/artifacts/sparkle/Sparkle/bin"

echo "=== 生成 appcast 条目 ==="
"${SPARKLE_BIN}/generate_appcast" "$DMG_PATH"

echo ""
echo "appcast.xml 已生成在 DMG 同目录下"
echo "请将其上传到: https://huaguan.github.io/typeback/appcast.xml"