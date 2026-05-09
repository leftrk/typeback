# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

TypeBack 是一个 macOS Menu Bar 应用，在切换到中文输入法后，停顿一段时间自动回切英文。不含测试，无外部依赖。

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

## 架构

### 数据流

```
KeyEventMonitor（CGEventTap）
    ↓ onKeyEvent / onEsc
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
- **`KeyEventMonitor`** — 使用 `CGEventTap` 监听全局键盘事件，在 `AppDelegate` 完成 dispatch
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
