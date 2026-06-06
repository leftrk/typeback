#!/bin/bash
# TypeBack 打包脚本：构建 → 签名 → 公证 → staple → DMG → 公证 DMG → appcast
#
# 用法:
#   ./package.sh                  # 完整发布流程（含公证，需联网）
#   ./package.sh --skip-notarize  # 仅构建+签名+打 DMG，跳过公证（快速本地验证）
#   ./package.sh --no-fancy       # 兼容旧参数；当前 DMG 流程不依赖 Finder 美化
#   可组合: ./package.sh --skip-notarize --no-fancy
#
# 产物：dist/TypeBack.app（已签名/公证/staple）、dist/TypeBack.zip、dist/TypeBack.dmg

set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="TypeBack"
APP_VERSION="$(tr -d '[:space:]' < VERSION)"
BUNDLE_ID="${BUNDLE_ID:-com.huaguan.typeback}"

# 公证 keychain profile（由 notarytool store-credentials 预先配置）
NOTARY_PROFILE="${NOTARY_PROFILE:-typeback-notary}"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: Hua Guan (PP9XRDW4F5)}"

# Sparkle 配置
SU_FEED_URL="${SU_FEED_URL:-https://leftrk.github.io/homebrew-tap/appcast.xml}"
SU_PUBLIC_ED_KEY="${SU_PUBLIC_ED_KEY:-a9nYk9K6qPR+pXX2YjMfrif0HCCfZlAUdInFHm77DnU=}"  # EdDSA 公钥

# 图标源：优先仓库内固定位置，回落到 /tmp（兼容旧流程）
ICON_SRC="AppIcon.icns"
[ -f "$ICON_SRC" ] || ICON_SRC="/tmp/${APP_NAME}.icns"

# 路径
BUILD_DIR=""
SPARKLE_FRAMEWORK_PATH="${SPARKLE_FRAMEWORK_PATH:-}"
APP_DIR="dist/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
FRAMEWORKS_DIR="${CONTENTS_DIR}/Frameworks"
ZIP_PATH="dist/${APP_NAME}.zip"
DMG_PATH="dist/${APP_NAME}.dmg"

# 参数解析
SKIP_NOTARIZE=0
NO_FANCY=0
for arg in "$@"; do
    case "$arg" in
        --skip-notarize) SKIP_NOTARIZE=1 ;;
        --no-fancy)      NO_FANCY=1 ;;
        *) echo "未知参数: $arg"; exit 1 ;;
    esac
done

# 生成标准拖拽安装布局的 DMG。
# 不依赖 Finder/AppleScript 美化，避免 macOS 26 上 Finder 元数据或 provenance xattr
# 污染已签名的 .app bundle。
create_dmg() {
    rm -f "${DMG_PATH}"
    rm -rf "dist/dmg-stage"
    mkdir -p "dist/dmg-stage"
    ditto --noextattr --noqtn "${APP_DIR}" "dist/dmg-stage/${APP_NAME}.app"
    ln -s /Applications "dist/dmg-stage/Applications"
    xattr -cr "dist/dmg-stage/${APP_NAME}.app"
    codesign --verify --deep --strict --verbose=2 "dist/dmg-stage/${APP_NAME}.app"

    hdiutil create \
        -volname "${APP_NAME}" \
        -srcfolder "dist/dmg-stage" \
        -format UDZO \
        -fs APFS \
        -ov \
        "${DMG_PATH}"
}

require_tool() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "错误: 缺少依赖工具: $1"
        exit 1
    fi
}

require_tool swift
require_tool codesign
require_tool ditto
require_tool install_name_tool
require_tool xattr
require_tool hdiutil

find_sparkle_framework() {
    if [ -n "${SPARKLE_FRAMEWORK_PATH}" ]; then
        if [ -d "${SPARKLE_FRAMEWORK_PATH}" ]; then
            printf '%s\n' "${SPARKLE_FRAMEWORK_PATH}"
            return 0
        fi
        echo "错误: SPARKLE_FRAMEWORK_PATH 不存在: ${SPARKLE_FRAMEWORK_PATH}" >&2
        return 1
    fi

    local candidates=(
        "${BUILD_DIR}/Sparkle.framework"
        ".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
        ".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-x86_64/Sparkle.framework"
    )
    local candidate
    for candidate in "${candidates[@]}"; do
        if [ -d "${candidate}" ]; then
            printf '%s\n' "${candidate}"
            return 0
        fi
    done

    echo "错误: 未找到 Sparkle.framework。请先运行 swift build -c release。" >&2
    return 1
}

echo "=== 构建 Release 版本 ==="
swift build -c release
BUILD_DIR="$(swift build -c release --show-bin-path)"

echo "=== 创建 App Bundle ==="
rm -rf dist
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"
mkdir -p "${FRAMEWORKS_DIR}"

# 复制可执行文件
cp "${BUILD_DIR}/TypeBack" "${MACOS_DIR}/TypeBack"

# 添加 Frameworks rpath（Sparkle 需要）
install_name_tool -add_rpath "@executable_path/../Frameworks" "${MACOS_DIR}/TypeBack"
echo "已添加 @executable_path/../Frameworks rpath"

# 复制图标
if [ -f "${ICON_SRC}" ]; then
    cp "${ICON_SRC}" "${RESOURCES_DIR}/AppIcon.icns"
    echo "已嵌入图标: ${ICON_SRC}"
else
    echo "⚠️  未找到图标 ${ICON_SRC}，跳过（app 将无图标）"
fi

# 复制 Sparkle.framework。TypeBack 可执行文件链接到 @rpath/Sparkle.framework；
# 缺失 framework 时必须失败，不能产出无法启动的 app bundle。
SPARKLE_SOURCE="$(find_sparkle_framework)"
cp -R "${SPARKLE_SOURCE}" "${FRAMEWORKS_DIR}/"
codesign --force --deep --sign "${SIGN_IDENTITY}" \
    --options runtime \
    "${FRAMEWORKS_DIR}/Sparkle.framework"
echo "Sparkle.framework 已嵌入并签名: ${SPARKLE_SOURCE}"

# 创建 Info.plist
cat > "${CONTENTS_DIR}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>TypeBack</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${APP_VERSION}</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024 Hua Guan. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
    <key>SUFeedURL</key>
    <string>${SU_FEED_URL}</string>
EOF

# 添加公钥（如果有）
if [ -n "${SU_PUBLIC_ED_KEY}" ]; then
    cat >> "${CONTENTS_DIR}/Info.plist" << EOF
    <key>SUPublicEDKey</key>
    <string>${SU_PUBLIC_ED_KEY}</string>
EOF
fi

# 关闭 plist
cat >> "${CONTENTS_DIR}/Info.plist" << EOF
</dict>
</plist>
EOF

echo "=== 清理扩展属性 ==="
xattr -cr "${APP_DIR}"

echo "=== 签名应用 ==="
codesign --force --deep --sign "${SIGN_IDENTITY}" \
    --options runtime \
    --entitlements Entitlements.plist \
    "${APP_DIR}"

echo "=== 验证签名 ==="
codesign --verify --deep --strict --verbose=2 "${APP_DIR}"

echo "=== 打包 ZIP（用于公证）==="
ditto -c -k --keepParent "${APP_DIR}" "${ZIP_PATH}"

if [ "${SKIP_NOTARIZE}" -eq 1 ]; then
    echo ""
    echo "⏭  已跳过公证（--skip-notarize）"
    echo "=== 生成 DMG（未公证）==="
    create_dmg
    echo "=== 验证 DMG 生成后 App 签名 ==="
    codesign --verify --deep --strict --verbose=2 "${APP_DIR}"
    echo ""
    echo "✅ 构建完成（未公证）: ${DMG_PATH}"
    exit 0
fi

echo "=== 公证 App ==="
xcrun notarytool submit "${ZIP_PATH}" --keychain-profile "${NOTARY_PROFILE}" --wait

echo "=== Staple App ==="
xcrun stapler staple "${APP_DIR}"
xcrun stapler validate "${APP_DIR}"
spctl --assess --type execute --verbose "${APP_DIR}"

# 生成 DMG（封装已 staple 的 app）
echo "=== 生成 DMG ==="
create_dmg
echo "=== 验证 DMG 生成后 App 签名 ==="
codesign --verify --deep --strict --verbose=2 "${APP_DIR}"

echo "=== 签名 DMG ==="
codesign --force --sign "${SIGN_IDENTITY}" "${DMG_PATH}"

echo "=== 公证 DMG ==="
xcrun notarytool submit "${DMG_PATH}" --keychain-profile "${NOTARY_PROFILE}" --wait

echo "=== Staple DMG ==="
xcrun stapler staple "${DMG_PATH}"
xcrun stapler validate "${DMG_PATH}"
spctl --assess --type install --verbose "${DMG_PATH}"

DMG_SHA=$(shasum -a 256 "${DMG_PATH}" | awk '{print $1}')

echo ""
echo "✅ 打包完成: ${DMG_PATH}"
echo "   版本:   ${APP_VERSION}"
echo "   sha256: ${DMG_SHA}"
echo ""
echo "下一步："
echo "  1. 生成 appcast 条目:  ./generate_appcast.sh"
echo "  2. 创建 GitHub release: gh release create v${APP_VERSION} ${DMG_PATH}"
echo "  3. 更新 homebrew tap:   version=${APP_VERSION} sha256=${DMG_SHA}"
