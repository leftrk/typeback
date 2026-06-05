import AppKit
import Carbon
import SwiftUI
import Sparkle

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - 状态管理
    let appState = AppState()

    // MARK: - 核心服务
    private var inputSourceHelper = InputSourceHelper()
    private var keyEventMonitor: KeyEventMonitor?
    private var candidateBoxDetector: CandidateBoxDetector?
    private var typingStateDetector: TypingStateDetector?
    private var inputCheckTimer: Timer?

    // MARK: - UI 控制器
    private var floatingIndicator: FloatingIndicatorController?
    private var menuBarController: MenuBarController?
    private var settingsController: SettingsController?

    // MARK: - Sparkle 更新器
    private var updaterController: SPUStandardUpdaterController?

    // MARK: - 生命周期
    func applicationWillFinishLaunching(_ notification: Notification) {
        // macOS 26 (Tahoe) 上，NSStatusItem 需在 activation policy 设置前注册。
        // 将 setActivationPolicy(.accessory) 移至此处，避免状态项被分配到屏幕外的隐藏区域。
        // 同时从 Info.plist 移除 LSUIElement（该键在 Tahoe 上会导致菜单栏图标不显示）。
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        logInfo("应用启动")

        // 初始化 Sparkle 更新器
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        guard PermissionsHelper.isAccessibilityEnabled() else {
            logError("缺少辅助功能权限")
            showPermissionAlert()
            return
        }

        setupServices()
        setupUI()
        observeShortcutChanges()

        logInfo("应用初始化完成")
    }

    func applicationWillTerminate(_ notification: Notification) {
        logInfo("应用即将退出")

        inputCheckTimer?.invalidate()
        Task {
            await typingStateDetector?.stop()
        }
        keyEventMonitor?.stop()
        candidateBoxDetector?.stop()
    }

    // MARK: - 服务设置
    private func setupServices() {
        candidateBoxDetector = CandidateBoxDetector(
            onCandidateBoxStateChanged: { [weak self] hasBox in
                Task { @MainActor [weak self] in
                    if hasBox {
                        await self?.typingStateDetector?.resetTyping()
                    }
                }
            }
        )
        candidateBoxDetector?.start()

        keyEventMonitor = KeyEventMonitor(
            shortcut: appState.shortcut,
            onKeyEvent: { [weak self] in
                Task { @MainActor [weak self] in
                    self?.handleKeyEvent()
                }
            },
            onShortcut: { [weak self] in
                Task { @MainActor [weak self] in
                    self?.handleShortcut()
                }
            }
        )
        let keyMonitorStarted = keyEventMonitor?.start() ?? false
        logInfo("键盘监听 \(keyMonitorStarted ? "已启动" : "启动失败")")

        typingStateDetector = TypingStateDetector(
            typingEndDelay: 2.0,
            onStateChanged: { [weak self] state in
                Task { @MainActor [weak self] in
                    self?.handleTypingStateChange(state)
                }
            }
        )
        Task {
            await typingStateDetector?.start()
        }

        inputCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkCurrentInputSource()
            }
        }
    }

    // MARK: - UI 设置
    private func setupUI() {
        floatingIndicator = FloatingIndicatorController(appState: appState)
        floatingIndicator?.show()

        settingsController = SettingsController(
            appState: appState,
            startRecording: { [weak self] handler in
                self?.keyEventMonitor?.startRecording(handler: handler)
            },
            stopRecording: { [weak self] in
                self?.keyEventMonitor?.stopRecording()
            }
        )

        menuBarController = MenuBarController(
            appState: appState,
            updater: updaterController?.updater,
            onOpenSettings: { [weak self] in self?.openSettings() },
            onQuit: { NSApp.terminate(nil) }
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleToggleInputMethod),
            name: .toggleInputMethod,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenSettingsNotification),
            name: .openSettings,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    // MARK: - 快捷键变更追踪
    /// 用 Observation 追踪 appState.shortcut 变化，同步到 KeyEventMonitor
    private func observeShortcutChanges() {
        withObservationTracking {
            _ = appState.shortcut
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.keyEventMonitor?.updateShortcut(self.appState.shortcut)
                self.observeShortcutChanges()
            }
        }
    }

    // MARK: - 事件处理

    private func handleKeyEvent() {
        guard appState.isChinese else { return }
        Task {
            await typingStateDetector?.resetTyping()
        }
    }

    /// 用户按下「立即回英文」快捷键
    private func handleShortcut() {
        appState.shortcutFlash = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            appState.shortcutFlash = false
        }
        switchToEnglish()

        // 候选框存在时，发 ESC 清除残留候选框
        if candidateBoxDetector?.hasCandidateBox == true {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 100_000_000)
                postVirtualKey(keyCode: kVK_Escape)
            }
        }
    }

    private func handleTypingStateChange(_ state: TypingState) {
        switch state {
        case .typing:
            appState.setTyping()

        case .idle:
            appState.setIdle()
            guard appState.autoSwitchEnabled else { return }
            let timeout = appState.timeoutSeconds
            Task {
                await typingStateDetector?.startCountdown(seconds: timeout)
            }

        case .countdown(let seconds):
            appState.setCountdown(seconds)

        case .timeout:
            appState.setCountdown(0)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 250_000_000)
                self.switchToEnglish()
            }
        }
    }

    private func checkCurrentInputSource() {
        let isEnglish = inputSourceHelper.isCurrentInputSourceEnglish()

        if isEnglish && !appState.isEnglish {
            appState.setEnglish()
        } else if !isEnglish && appState.isEnglish {
            appState.setChinese()
        }
    }

    // MARK: - 操作

    /// 发送虚拟按键事件（用于清除候选框等场景）
    private func postVirtualKey(keyCode: Int) {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: false)
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func switchToEnglish() {
        guard appState.isChinese else { return }

        floatingIndicator?.flash()
        let success = inputSourceHelper.switchToEnglish()

        if success {
            appState.setEnglish()
        } else {
            logError("切换到英文输入法失败")
        }
    }

    func toggleInputMethod() {
        if appState.isEnglish {
            let success = inputSourceHelper.switchToChinese()
            if success {
                appState.setChinese()
            }
        } else {
            switchToEnglish()
        }
    }

    private func openSettings() {
        settingsController?.show()
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = "TypeBack 需要辅助功能权限来监听键盘事件。\n请在 系统设置 → 隐私与安全性 → 辅助功能 中授权。"
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "退出")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            PermissionsHelper.openAccessibilitySettings()
        }
        NSApp.terminate(nil)
    }

    // MARK: - 通知处理
    @objc private func handleToggleInputMethod() {
        toggleInputMethod()
    }

    @objc private func handleOpenSettingsNotification() {
        openSettings()
    }

    @objc private func handleDidWake() {
        switchToEnglish()
    }
}
