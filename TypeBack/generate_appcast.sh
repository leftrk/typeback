#!/bin/bash
# TypeBack appcast 生成脚本
#
# 在一个干净的临时目录中对 DMG 运行 Sparkle generate_appcast，
# 避免把 dist/ 下的 .zip 也算进 appcast，并直接写入指向 GitHub release 的下载地址。
#
# 用法: ./generate_appcast.sh [DMG路径]   （默认 dist/TypeBack.dmg）
# 输出: dist/appcast.xml

set -e

cd "$(dirname "$0")"

APP_NAME="TypeBack"
APP_VERSION="1.1.0"
DMG_PATH="${1:-dist/${APP_NAME}.dmg}"

# release 下载地址前缀：generate_appcast 会据此生成 enclosure url
DOWNLOAD_URL_PREFIX="https://github.com/leftrk/typeback/releases/download/v${APP_VERSION}/"
PROJECT_LINK="https://github.com/leftrk/typeback"

SPARKLE_BIN=".build/artifacts/sparkle/Sparkle/bin"

if [ ! -f "$DMG_PATH" ]; then
    echo "错误: DMG 文件不存在: $DMG_PATH"
    exit 1
fi

if [ ! -x "${SPARKLE_BIN}/generate_appcast" ]; then
    echo "错误: 找不到 generate_appcast，请先运行 swift build -c release"
    exit 1
fi

# 干净临时目录，只放当前 DMG，避免 zip 等其它归档混入 appcast
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT
cp "$DMG_PATH" "$WORK_DIR/"

echo "=== 生成 appcast 条目 ==="
"${SPARKLE_BIN}/generate_appcast" \
    --download-url-prefix "${DOWNLOAD_URL_PREFIX}" \
    --link "${PROJECT_LINK}" \
    "$WORK_DIR"

cp "$WORK_DIR/appcast.xml" "dist/appcast.xml"

echo ""
echo "✅ appcast.xml 已生成: dist/appcast.xml"
echo "   请将其内容同步到 homebrew-tap 仓库的 appcast.xml"
