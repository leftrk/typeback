# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

TypeBack 是一个 macOS Menu Bar 应用。核心：
- 浮动指示器实时显示当前输入法状态（带光晕和状态切换水波动画）
- 用户自定义快捷键一键切回英文（默认 ⌃Space）
- 中文停顿超时后自动回切英文（可关闭）
- Caps Lock 可设为仅切换输入法（可选）

不含测试，无外部依赖。

## 常用命令

所有命令在 `TypeBack/` 目录下执行：

```bash
cd TypeBack

# 构建（debug）
swift build

# 运行（构建+启动）
./run.sh

# 直接运行已构建产物
.build/debug/TypeBack

# release 构建
swift build -c release
```

首次运行需在 **系统设置 → 隐私与安全性 → 辅助功能** 授权终端/TypeBack。

## 发布身份与兼容性硬约束

- **正式 Bundle ID 固定为 `com.typeback.app`，不要再改。**
- `TypeBack/package.sh` 的默认 `BUNDLE_ID` 必须保持 `com.typeback.app`。
- `Logger` 的 subsystem 使用 `com.typeback.app`，应与正式 Bundle ID 保持一致。
- 旧身份 `com.huaguan.typeback`、`com.huaguan.typeback.app`、`com.leftrk.typeback` 只作为历史迁移/清理对象存在，不应重新作为正式身份。
- 修改 Bundle ID 会让 macOS 把应用视为全新程序，导致辅助功能权限、菜单栏设置、LaunchServices、TCC、UserDefaults 全部重新分叉；除非明确做版本迁移，不要改。
- 当前版本目标兼容 macOS 14~26：`Package.swift` 使用 `.macOS(.v14)`，Homebrew cask 使用 `depends_on macos: :sonoma`（bare symbol，新版 Homebrew 解析为「>= 14」最小版本；旧的字符串写法 `">= :sonoma"` 已被废弃会报 warning，不要改回）。
- `Info.plist` 不写 `LSMinimumSystemVersion`；最低系统版本由 SwiftPM deployment target 和 Homebrew cask 约束。不要为了“补全 plist”重新加回该字段。
- SwiftUI Observation、`@Observable`、`PhaseAnimator` 等都依赖 macOS 14 起步；新增 API 若高于 macOS 14，必须用 `#available`/`@available` 门控或换成 macOS 14 可用写法。

## 发布与分发

- 分发渠道只保留 GitHub Release DMG + Homebrew cask。
- 不再使用 Sparkle、appcast、`generate_appcast.sh`、Sparkle XPC 或自动更新框架。
- App 必须是菜单栏应用，不出现在 Dock：`Info.plist` 保持 `LSUIElement=true`。
- App 入口使用传统 AppKit `@main`：`Sources/TypeBack/App/TypeBackMain.swift` 创建 `NSApplication.shared` 并挂载 `AppDelegate`。
- 菜单栏入口保持最小原生实现：`NSStatusItem` + `NSMenu`。
- 菜单栏图标使用 SF Symbol `character.cursor.ibeam`；`TB` 只作为 symbol 不存在时的 fallback，不作为默认 UI。
- DMG 打包使用标准拖拽布局，不做 Finder/AppleScript 美化，避免 Finder 元数据或 provenance xattr 污染签名后的 app bundle。

## macOS 26 菜单栏缓存排查结论

- macOS 26 上旧 `com.huaguan.typeback` 菜单栏状态曾被系统缓存污染；最小 `NSStatusItem` 探针复用该旧 Bundle ID 也不显示，证明根因不是业务代码。
- 使用新正式身份 `com.typeback.app` 后菜单栏可正常显示；因此该身份是长期固定身份。
- “系统设置 → 控制中心/菜单栏”中出现多个 TypeBack 条目时，主要来源不是 TCC，而是：
  - `~/Library/Group Containers/group.com.apple.controlcenter/Library/Preferences/group.com.apple.controlcenter.plist`
  - key：`trackedApplications`
  - 该值内部是嵌套 binary plist，可能残留旧 Bundle ID、`com.test.*` 探针、以及 `.build/.../TypeBack` 临时二进制路径。
- 修复重复菜单栏条目时，不要重置整份 Control Center plist；应先备份，再只删除 TypeBack/test/临时构建相关记录，保留其它应用设置。
- 清理后重启 `cfprefsd`、`ControlCenter`、`SystemUIServer` 和 TypeBack。
- TCC 系统库 `/Library/Application Support/com.apple.TCC/TCC.db` 可能残留旧辅助功能行，但受 SIP/TCC 保护时即使 sudo 也可能 readonly；这些旧行不是“菜单栏”重复项的主要来源。
- LaunchServices 可能残留旧 `/Volumes/dmg.*`、`.Trash/TypeBack.app` 或 probe 注册；macOS 26 上 `lsregister -kill` 已移除，不要依赖旧系统的全量重建命令。

## 架构

### 数据流

```
KeyEventMonitor（CGEventTap）
    ↓ onKeyEvent / onShortcut
AppDelegate（@MainActor）
    ↓ resetTyping / startCountdown
TypingStateDetector（actor）
    ↓ onStateChanged: .typing / .idle / .countdown / .timeout
AppDelegate
    ↓ appState.set*()
AppState（@Observable @MainActor）
    ↓ SwiftUI binding
FloatingIndicatorController / MenuBarController / SettingsController
```

### 核心层（`Core/`）

- **`AppState`** — 唯一的全局状态源（`@Observable @MainActor`），持久化到 `UserDefaults`；UI 组件直接观察它
- **`TypingStateDetector`** — `actor`，用 Swift Concurrency `Task` 替代 `Timer` 做倒计时，避免 RunLoop 依赖；通过回调向 `AppDelegate` 报告 `.typing / .idle / .countdown / .timeout`
- **`KeyEventMonitor`** — 使用 `CGEventTap` 监听全局键盘事件，匹配用户配置的快捷键时触发 `onShortcut`；运行时可通过 `updateShortcut(_:)` 动态更新
- **`ShortcutRecorder`** — 临时 `NSEvent.addLocalMonitorForEvents` 监听器，捕获用户按下的一次完整组合键
- **`CandidateBoxDetector`** — 通过 AX API 检测输入法候选框，有候选框时阻止倒计时切换
- **`CapsLockGuard`** — 可选功能，拦截 Caps Lock 防误触

### UI 层（`UI/`）

- **`FloatingIndicatorController`** — `NSPanel`（非激活浮动窗口），托管 `IndicatorContentView`（SwiftUI），拖动位置持久化到 `AppState`
- **`MenuBarController`** — `NSStatusItem`，操作通过闭包回调到 `AppDelegate`
- **`SettingsController`** — `NSWindow` 托管 `SettingsView`（SwiftUI），设置写入 `AppState` 后自动同步 `UserDefaults`

### UI 与状态通信

- **`AppDelegate → UI`**：直接持有 Controller 引用并调用方法（如 `floatingIndicator?.flash()`）
- **`UI → AppDelegate`**：`NotificationCenter`（`.toggleInputMethod`、`.openSettings`）或闭包回调
- **`AppState → SwiftUI`**：`@Observable` 自动追踪，无需手动 `objectWillChange`

### 关键约束

- `AppDelegate` 和所有 UI 操作必须在 `@MainActor`，与 `actor` 交互需 `Task { await ... }`
- `InputSourceHelper` 封装 TIS API（`TISSelectInputSource`），切换输入法后通过 0.5s 轮询（`inputCheckTimer`）同步 `AppState`
- 最低 macOS 14.0，使用 `PhaseAnimator` 做多层呼吸动画（需 macOS 17 API 时注意版本门控）
- `KeyEventMonitor` 是 `@unchecked Sendable`，跨线程访问当前快捷键用 `OSAllocatedUnfairLock`
- `AppDelegate.observeShortcutChanges` 用 `withObservationTracking` 追踪 `appState.shortcut`，在 onChange 中递归重新订阅以持续监听
- 指示器 panel **不再设置 `.fullScreenAuxiliary`**，所以全屏应用激活时指示器不会跟到全屏 Space
