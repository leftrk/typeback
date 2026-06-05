#!/bin/bash
# TypeBack 打包脚本：构建 → 签名 → 公证 → staple → DMG → 公证 DMG → appcast
#
# 用法:
#   ./package.sh                  # 完整发布流程（含公证，需联网，需 GUI 会话美化 DMG）
#   ./package.sh --skip-notarize  # 仅构建+签名+打 DMG，跳过公证（快速本地验证）
#   ./package.sh --no-fancy       # 跳过 DMG Finder 美化（CI / 后台 / 无 GUI 环境）
#   可组合: ./package.sh --skip-notarize --no-fancy
#
# 产物：dist/TypeBack.app（已签名/公证/staple）、dist/TypeBack.zip、dist/TypeBack.dmg

set -e

cd "$(dirname "$0")"

TEAM_ID="PP9XRDW4F5"
APP_NAME="TypeBack"
APP_VERSION="1.1.1"
BUNDLE_ID="com.huaguan.typeback"

# 公证 keychain profile（由 notarytool store-credentials 预先配置）
NOTARY_PROFILE="typeback-notary"
SIGN_IDENTITY="Developer ID Application: Hua Guan (${TEAM_ID})"

# Sparkle 配置
SU_FEED_URL="https://leftrk.github.io/homebrew-tap/appcast.xml"
SU_PUBLIC_ED_KEY="a9nYk9K6qPR+pXX2YjMfrif0HCCfZlAUdInFHm77DnU="  # EdDSA 公钥

# 图标源：优先仓库内固定位置，回落到 /tmp（兼容旧流程）
ICON_SRC="AppIcon.icns"
[ -f "$ICON_SRC" ] || ICON_SRC="/tmp/${APP_NAME}.icns"

# 路径
BUILD_DIR=".build/release"
FRAMEWORK_DIR=".build/arm64-apple-macosx/release"
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

# 用 create-dmg 生成标准拖拽安装布局的 DMG。
# 默认带 Finder 窗口美化（需 GUI 会话）；--no-fancy 跳过美化，
# 适用于 CI / 后台 / 无登录会话环境（否则 osascript 美化步骤会卡住或留下 rw.*.dmg）。
create_dmg() {
    rm -f "${DMG_PATH}"
    local fancy_args=(
        --volname "${APP_NAME}"
        --window-pos 200 120
        --window-size 600 360
        --icon-size 100
        --icon "${APP_NAME}.app" 150 180
        --hide-extension "${APP_NAME}.app"
        --app-drop-link 450 180
        --no-internet-enable
    )
    [ "${NO_FANCY}" -eq 1 ] && fancy_args+=(--skip-jenkins)
    create-dmg "${fancy_args[@]}" "${DMG_PATH}" "${APP_DIR}"
}

echo "=== 构建 Release 版本 ==="
swift build -c release

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

# 复制 Sparkle.framework
if [ -d "${FRAMEWORK_DIR}/Sparkle.framework" ]; then
    cp -R "${FRAMEWORK_DIR}/Sparkle.framework" "${FRAMEWORKS_DIR}/"
    # 签名 Sparkle.framework
    codesign --force --deep --sign "${SIGN_IDENTITY}" \
        --options runtime \
        "${FRAMEWORKS_DIR}/Sparkle.framework"
    echo "Sparkle.framework 已签名"
fi

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
