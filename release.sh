#!/bin/bash
# TypeBack 一键发版：打包 → GitHub Release → 同步 cask 到 homebrew-tap
#
# 用法:
#   ./release.sh                 # 完整流程（含公证，需联网）
#   ./release.sh --skip-release  # 只打包并同步 cask，不创建 GitHub Release（调试用）
#
# 环境变量:
#   TAP_DIR   homebrew-tap 本地仓库路径（默认: ../homebrew-tap）
#   其余透传给 package.sh：BUNDLE_ID / SIGN_IDENTITY / NOTARY_PROFILE
#
# 前置条件:
#   - 已 bump VERSION 文件
#   - gh 已登录且有 leftrk/typeback 的 release 权限
#   - homebrew-tap 本地仓库干净且在可推送的分支上

set -euo pipefail

cd "$(dirname "$0")"

APP_VERSION="$(tr -d '[:space:]' < VERSION)"
TAG="v${APP_VERSION}"
DMG_PATH="dist/TypeBack.dmg"
CASK_TEMPLATE="Casks/typeback.rb"

TAP_DIR="${TAP_DIR:-../homebrew-tap}"
TAP_DIR="$(cd "${TAP_DIR}" && pwd)"
CASK_TARGET="${TAP_DIR}/Casks/typeback.rb"

SKIP_RELEASE=0
for arg in "$@"; do
    case "$arg" in
        --skip-release) SKIP_RELEASE=1 ;;
        *) echo "未知参数: $arg"; exit 1 ;;
    esac
done

if [ "${SKIP_RELEASE}" -eq 0 ] && gh release view "${TAG}" >/dev/null 2>&1; then
    echo "错误: GitHub Release ${TAG} 已存在，请先 bump VERSION"
    exit 1
fi

if [ -n "$(git -C "${TAP_DIR}" status --porcelain)" ]; then
    echo "错误: ${TAP_DIR} 有未提交的改动，请先处理"
    exit 1
fi

echo "=== 打包（含公证）==="
./package.sh --no-fancy

DMG_SHA=$(shasum -a 256 "${DMG_PATH}" | awk '{print $1}')

if [ "${SKIP_RELEASE}" -eq 0 ]; then
    echo "=== 创建 GitHub Release ${TAG} ==="
    gh release create "${TAG}" "${DMG_PATH}" --title "${TAG}" --generate-notes
fi

echo "=== 同步 cask 到 ${CASK_TARGET} ==="
sed -e "s/version \"VERSION\"/version \"${APP_VERSION}\"/" \
    -e "s/sha256 \"SHA256\"/sha256 \"${DMG_SHA}\"/" \
    "${CASK_TEMPLATE}" > "${CASK_TARGET}"

git -C "${TAP_DIR}" add Casks/typeback.rb
git -C "${TAP_DIR}" commit -m "typeback ${APP_VERSION}"
git -C "${TAP_DIR}" push

echo ""
echo "✅ 发版完成: ${TAG}"
echo "   sha256: ${DMG_SHA}"
echo "   cask 已推送: ${CASK_TARGET}"
