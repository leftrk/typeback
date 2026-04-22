# TypeBack

macOS 输入法自动回切工具 - 采用 iOS 26 Liquid Glass 设计风格

## 功能特性

- **智能自动回切**: 打完中文后，停顿 2 秒开始倒计时，N 秒后自动切回英文输入法
- **双击 ESC**: 快速双击 ESC 键立即切回英文 (500ms 内)
- **现代浮动指示器**: 
  - iOS 26 Liquid Glass 设计风格
  - 胶囊形状、高度透明、毛玻璃效果
  - 多层呼吸动画（Scale、Opacity、Color 脉动）
  - 状态颜色指示（绿色=英文，红色=中文）
  - 可拖动定位，自动记忆位置
- **Per-App 规则**: 不同 App 可设置不同的超时时间
- **系统唤醒**: 电脑唤醒后自动切回英文
- **候选框检测**: 检测输入法候选窗口，避免强制切换

## 设计亮点

### 浮动指示器
- 玻璃质感背景（`.ultraThinMaterial`）
- 动态外发光层随状态强度变化
- 呼吸动画周期（Scale 4s, Glow 5s）形成自然呼吸感
- 倒计时最后 10 秒显示秒数徽章

### 设置面板
- 卡片式布局设计
- 现代分段选择器（胶囊形选中指示）
- Per-App 规则以徽章显示超时时间
- 简洁的层级排版和色彩系统

## 构建

```bash
cd TypeBack
swift build
```

## 运行

```bash
.build/debug/TypeBack
```

或使用快捷脚本：
```bash
./run.sh
```

## 权限

首次运行需要授权 **辅助功能权限**：

1. 系统设置 → 隐私与安全性 → 辅助功能
2. 添加 TypeBack（或终端/Terminal 如果从终端运行）

## 配置

点击菜单栏图标或双击浮动指示器打开设置面板：

### 通用设置
- **默认超时时间**: 30s / 60s / 120s
- **回切目标输入法**: ABC / US / British

### Per-App 规则
为特定 App 设置独立超时，默认预设：

| App | 超时 |
|-----|------|
| Terminal / iTerm2 | 15s |
| VS Code / Xcode | 30s |
| 微信 | 120s |
| Safari / Chrome | 60s |

### 行为设置
- **开机自启动**: 登录后自动启动
- **唤醒即切英文**: 电脑唤醒后自动切到英文

## 项目结构

```
TypeBack/
├── Sources/TypeBack/
│   ├── App/
│   │   ├── TypeBackApp.swift      # App 入口 (SwiftUI)
│   │   └── AppDelegate.swift      # 生命周期管理
│   ├── Core/
│   │   ├── SharedTypes.swift      # 共享类型定义
│   │   ├── TypingStateDetector.swift  # 打字状态检测
│   │   ├── KeyEventMonitor.swift      # 键盘事件监听 (CGEventTap)
│   │   └── CandidateBoxDetector.swift # 候选框检测
│   ├── UI/
│   │   ├── FloatingIndicator/
│   │   │   ├── FloatingIndicatorController.swift  # 浮动窗口
│   │   │   └── IndicatorContentView.swift         # SwiftUI 视图
│   │   ├── MenuBar/
│   │   │   └ MenuBarController.swift # 菜单栏图标
│   │   └── Settings/
│   │       ├── SettingsController.swift # 设置窗口
│   │       └ SettingsView.swift        # SwiftUI 设置界面
│   └── Utils/
│       ├── InputSourceHelper.swift # 输入法操作 (TIS API)
│       └ PermissionsHelper.swift   # 权限检查
└── Package.swift
```

## 技术栈

- **语言**: Swift 5.10
- **UI 框架**: SwiftUI + AppKit (NSPanel 浮动窗口)
- **最低支持**: macOS 14.0 (Sonoma)
- **架构**: Menu Bar App (`LSUIElement = true`)
- **动画**: PhaseAnimator 多层呼吸动画

## 操作说明

| 操作 | 功能 |
|------|------|
| 单击浮动指示器 | 切换输入法 |
| 双击浮动指示器 | 打开设置 |
| 拖动浮动指示器 | 移动位置（自动保存） |
| 双击 ESC 键 | 立即切回英文 |
| 点击菜单栏图标 | 打开菜单 |

## 状态指示

- **EN (绿色)**: 当前英文输入法
- **中 (红色)**: 当前中文输入法
- **中 + 倒计时徽章**: 正在倒计时，即将切回英文
- **呼吸强度变化**: 
  - 英文: 低强度呼吸
  - 中文输入中: 高强度呼吸
  - 倒计时最后 5 秒: 最强呼吸警告

## 开源

本项目完全开源，无任何收费功能。

## License

MIT License