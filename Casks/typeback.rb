# TypeBack 的 Homebrew Cask 定义（事实来源在本仓库）。
# 发布时由 release.sh 替换 VERSION/SHA256 占位符后同步到 homebrew-tap，
# 请勿直接编辑 homebrew-tap 里的副本。
cask "typeback" do
  version "VERSION"
  sha256 "SHA256"

  url "https://github.com/leftrk/typeback/releases/download/v#{version}/TypeBack.dmg"
  name "TypeBack"
  desc "macOS 输入法自动回切工具"
  homepage "https://github.com/leftrk/typeback"

  depends_on macos: :sonoma

  app "TypeBack.app"

  zap trash: [
    "~/Library/Preferences/com.huaguan.typeback.plist",
    "~/Library/Preferences/TypeBack.plist",
    "~/Library/Preferences/TypeBackStandalone.plist",
    "~/Library/Preferences/com.huaguan.typeback.app.plist",
    "~/Library/Preferences/com.typeback.app.plist",
    "~/Library/Application Support/com.huaguan.typeback",
    "~/Library/Application Support/com.typeback.app",
    "~/Library/Caches/com.huaguan.typeback",
    "~/Library/Caches/com.typeback.app",
  ]

  caveats <<~EOS
    TypeBack 需要辅助功能权限才能监听键盘事件：
      系统设置 → 隐私与安全性 → 辅助功能 → 添加 TypeBack

    TypeBack 的正式应用身份固定为 com.typeback.app。如从旧身份版本升级，可能需要重新授权辅助功能权限。

    如 macOS 26 提示无法验证 TypeBack，可运行：
      xattr -dr com.apple.quarantine /Applications/TypeBack.app
  EOS
end
