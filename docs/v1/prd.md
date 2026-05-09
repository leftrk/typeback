# TypeBack 产品需求文档 (PRD)

## 1. 产品概述

TypeBack 是一款 macOS 输入法自动回切工具，专为 vim 用户和中文开发者设计。核心理念：**打完中文后，自动回到英文状态**。

目标用户：vim/终端用户，日常中英文混合输入者。

---

## 2. 核心行为

### 状态流转

```
英文 [EN]
    ↓ 用户切换到中文
中文·空闲 [CN]
    ↓ 有键盘活动
中文·输入中 [CN] → 停止输入 2 秒 → 中文·空闲 [CN]
    ↓ 无活动，开始倒计时
中文·倒计时 [CN + 进度弧] → 归零 → 切回英文 [EN]
```

### 行为规则

| 场景 | 行为 |
|------|------|
| 切到中文输入法 | 进入中文·空闲，等待键盘活动 |
| 中文模式下有键盘活动 | 重置倒计时，进入输入中状态 |
| 停止输入超过 2 秒 | 进入空闲，启动倒计时 |
| 倒计时归零 | 自动切回英文 |
| 按 ESC（中文模式） | 立即切回英文，ESC 事件穿透给前台应用 |
| 按 ESC（英文模式） | 不拦截 |
| 候选框打开时 | 重置倒计时，候选框关闭后重新开始 |
| 系统唤醒 | 自动切到英文 |

---

## 3. 浮动指示器

### 造型

圆形，52×52 外框，36px 表盘直径。

| 状态 | 表盘 | 字形 | 字色 |
|------|------|------|------|
| 英文 | 近白（0.97 白，90% 不透明） | EN | 黑色 45% 不透明 |
| 中文（空闲/输入中） | 近黑（0.12 白，90% 不透明） | CN | 白色 80% 不透明 |
| 中文（倒计时） | 近黑 | CN | 白色 80% 不透明 |

投影：`rgba(0,0,0,0.15)` blur 6 y 2，单层。

字体：SF Rounded，11px medium，tracking 0.3。

### 进度弧

倒计时时显示，顺时针消退（progress = 剩余秒/总时长）。白色，1.6px，圆头。

**仅有的动画**：倒计时最后 5 秒，弧线 opacity 在 0.5↔1.0 之间脉冲（0.9s 周期）。状态切换用 opacity 过渡（0.25–0.3s ease-in-out）。尊重 `accessibilityReduceMotion`，开启时禁用脉冲。

### 交互

| 操作 | 行为 |
|------|------|
| 单击 | 切换输入法 |
| 双击 | 打开设置 |
| 拖动 | 移动位置（自动保存） |

---

## 4. 菜单栏

图标：SF Symbol `keyboard`，isTemplate=true 自动适配外观，静态不随状态变化。

下拉菜单：

```
┌─────────────────────┐
│ 当前: 中文 (42s)     │  ← 状态文字，不可点击
├─────────────────────┤
│ 立即切回英文         │
│ 设置...       ⌘,    │
├─────────────────────┤
│ 退出 TypeBack        │
└─────────────────────┘
```

---

## 5. 设置窗口

宽 360px，自适应高度。三个设置项：

| 设置项 | 控件 | 选项/说明 |
|--------|------|-----------|
| 超时时间 | Picker | 30s / 60s / 120s，默认 60s |
| 禁用 Caps Lock | Toggle | 仅保留切换输入法，禁用长按锁定大写 |
| 开机自启动 | Toggle | 默认关，使用 SMAppService |

---

## 6. 权限引导

首次启动无辅助功能权限时，弹 NSAlert：两个按钮（打开系统设置 / 退出），点击「打开系统设置」后应用退出。

---

## 7. 技术规格

| 项目 | 选择 |
|------|------|
| 语言 | Swift 5.10 |
| UI 框架 | SwiftUI（设置/指示器内容）+ AppKit（NSPanel 浮动窗口） |
| 最低支持 | macOS 14.0 (Sonoma) |
| 架构 | Menu Bar App（`LSUIElement = true`） |

| 功能 | 实现 |
|------|------|
| 输入法切换 | TIS API（`TISSelectInputSource`） |
| 输入法状态同步 | 0.5s 轮询（`Timer`） |
| 键盘监听 | `CGEventTap` |
| 倒计时 | Swift Concurrency `Task`（无 RunLoop 依赖） |
| 候选框检测 | AX API |
| 开机自启动 | `SMAppService` |
| 系统唤醒监听 | `NSWorkspace.didWakeNotification` |

---

## 8. 模块结构

```
TypeBack/Sources/TypeBack/
├── App/
│   ├── TypeBackApp.swift          # SwiftUI App 入口
│   └── AppDelegate.swift          # 生命周期 + 事件总线
├── Core/
│   ├── SharedTypes.swift          # InputState 枚举
│   ├── AppState.swift             # @Observable 全局状态 + UserDefaults 持久化
│   ├── TypingStateDetector.swift  # actor，管理输入/空闲/倒计时状态机
│   ├── KeyEventMonitor.swift      # CGEventTap 键盘监听
│   ├── CandidateBoxDetector.swift # AX API 候选框检测
│   └── CapsLockGuard.swift        # 可选，拦截 Caps Lock 锁定行为
├── UI/
│   ├── FloatingIndicator/
│   │   ├── FloatingIndicatorController.swift  # NSPanel 窗口管理 + 拖动
│   │   └── IndicatorContentView.swift         # SwiftUI 圆形指示器
│   ├── MenuBar/
│   │   └── MenuBarController.swift
│   └── Settings/
│       ├── SettingsController.swift
│       └── SettingsView.swift
└── Utils/
    ├── InputSourceHelper.swift    # TIS API 封装
    ├── PermissionsHelper.swift    # 辅助功能权限检查
    └── Logger.swift
```
