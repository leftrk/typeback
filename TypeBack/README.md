# TypeBack

macOS 14~26 输入法状态可视化与自动回切工具。圆形浮动指示器实时显示输入法状态，按下自定义快捷键一键切回英文，或在中文停止输入超时后自动回切。

## 功能

- **状态可视化**：圆形浮动指示器随状态切换颜色与光晕，状态变化时水波扩散动画
- **自定义快捷键**：在设置中录制任意「修饰键 + 按键」组合，按下立即切回英文（默认 ⌃Space）
- **自动回切**：中文输入停止 2 秒开始倒计时，超时后自动切到英文（可在设置中关闭）
- **候选框感知**：输入法候选框打开时暂停倒计时
- **系统唤醒**：电脑唤醒后自动切到英文
- **Caps Lock 仅切换输入法**（可选）：打开后长按 Caps Lock 不再锁定大写
- **全屏不打扰**：全屏应用激活时指示器自动隐藏

## 构建与运行

```bash
cd TypeBack

# 构建 + 运行
./run.sh

# 仅构建
swift build

# 直接运行已构建产物
.build/debug/TypeBack
```

## 安装

发布版建议通过 Homebrew Cask 安装：

```bash
brew tap leftrk/tap
brew install --cask typeback
```

中国大陆网络环境下，如 Homebrew 或 SwiftPM 拉取依赖较慢，可先设置本机代理：

```bash
export HTTP_PROXY=http://127.0.0.1:7890
export HTTPS_PROXY=http://127.0.0.1:7890
export ALL_PROXY=socks5://127.0.0.1:7890
```

## 权限

首次运行需要授权 **辅助功能权限**：

系统设置 → 隐私与安全性 → 辅助功能 → 添加 TypeBack（或终端）

授权后 TypeBack 会自动启动键盘监听，不需要重启应用。

## 配置

单击指示器切换输入法，双击打开设置。也可点击菜单栏图标 → 设置。

| 设置项 | 默认值 | 说明 |
|--------|--------|------|
| 启用自动回切 | 开 | 关闭后只靠快捷键切回 |
| 停止输入后 | 60 秒 | 30 / 60 / 120 秒可选 |
| 立即回英文（快捷键） | ⌃Space | 可在设置中录制自定义组合 |
| Caps Lock 仅切换输入法 | 关 | 打开后长按不再锁定大写 |
| 开机自启动 | 关 | 使用 SMAppService |

## 项目结构

```
TypeBack/Sources/TypeBack/
├── App/           # App 入口 + 生命周期
├── Core/          # 状态机、键盘监听、候选框检测、快捷键录制
├── UI/            # 浮动指示器、菜单栏、设置窗口
└── Utils/         # TIS API、权限、日志
```

## 技术栈

- Swift 5.10，macOS 14.0+（目标兼容 macOS 14~26）
- SwiftUI + AppKit（NSPanel 浮动窗口）
- CGEventTap 全局键盘监听，TIS API 输入法切换

## License

MIT
