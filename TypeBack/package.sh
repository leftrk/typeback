#!/bin/bash
# TypeBack 打包、签名、公证脚本

set -e

cd "$(dirname "$0")"

TEAM_ID="PP9XRDW4F5"
APP_NAME="TypeBack"
APP_VERSION="1.0.2"
BUNDLE_ID="com.huaguan.typeback"

# Sparkle 配置 — 需要替换为你的实际值
SU_FEED_URL="https://leftrk.github.io/homebrew-tap/appcast.xml"
SU_PUBLIC_ED_KEY="a9nYk9K6qPR+pXX2YjMfrif0HCCfZlAUdInFHm77DnU="  # EdDSA 公钥

# 路径
BUILD_DIR=".build/release"
FRAMEWORK_DIR=".build/arm64-apple-macosx/release"
APP_DIR="dist/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
FRAMEWORKS_DIR="${CONTENTS_DIR}/Frameworks"

echo "=== 构建 Release 版本 ==="
swift build -c release

echo "=== 创建 App Bundle ==="
rm -rf dist
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"
mkdir -p "${FRAMEWORKS_DIR}"

# 复制可执行文件
cp "${BUILD_DIR}/TypeBack" "${MACOS_DIR}/TypeBack"

# 复制图标（如果有）
if [ -f "/tmp/TypeBack.icns" ]; then
    cp "/tmp/TypeBack.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi

# 复制 Sparkle.framework
if [ -d "${FRAMEWORK_DIR}/Sparkle.framework" ]; then
    cp -R "${FRAMEWORK_DIR}/Sparkle.framework" "${FRAMEWORKS_DIR}/"
    # 签名 Sparkle.framework
    codesign --force --deep --sign "Developer ID Application: Hua Guan (${TEAM_ID})" \
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
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
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
codesign --force --deep --sign "Developer ID Application: Hua Guan (${TEAM_ID})" \
    --options runtime \
    --entitlements Entitlements.plist \
    "${APP_DIR}"

echo "=== 验证签名 ==="
codesign --verify --deep --strict --verbose=2 "${APP_DIR}"
# spctl 会拒绝未公证的 app，先跳过
# spctl --assess --type execute --verbose "${APP_DIR}"

echo "=== 打包 ZIP ==="
cd dist
ditto -c -k --keepParent "${APP_NAME}.app" "${APP_NAME}.zip"

echo ""
echo "✅ 打包完成: dist/${APP_NAME}.zip"
echo ""
echo "下一步公证:"
echo "  xcrun notarytool submit dist/${APP_NAME}.zip --keychain-profile typeback-notary --wait"
echo "  xcrun stapler staple dist/${APP_NAME}.app"
echo ""
echo "生成 appcast:"
echo "  ./generate_appcast.sh dist/${APP_NAME}.dmg"