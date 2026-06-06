import AppKit
import Carbon
import SwiftUI

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
    private var permissionCheckTimer: Timer?
    private var servicesStarted = false

    // MARK: - UI 控制器
    private var floatingIndicator: FloatingIndicatorController?
    private var menuBarController: MenuBarController?
    private var settingsController: SettingsController?

    // MARK: - 生命周期
    func applicationWillFinishLaunching(_ notification: Notification) {
        setupMenuBar()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        logInfo("应用启动")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.finishStartup()
        }
    }

    private func finishStartup() {
        setupRemainingUI()
        observeShortcutChanges()
        startPermissionMonitoring()

        if PermissionsHelper.isAccessibilityEnabled() {
            appState.accessibilityPermissionGranted = true
            startCoreServicesIfPermitted()
        } else {
            appState.accessibilityPermissionGranted = false
            logWarning("缺少辅助功能权限，等待用户授权")
            PermissionsHelper.requestAccessibilityPermissionPrompt()
        }

        logInfo("应用初始化完成")
    }

    func applicationWillTerminate(_ notification: Notification) {
        logInfo("应用即将退出")

        inputCheckTimer?.invalidate()
        permissionCheckTimer?.invalidate()
        Task {
            await typingStateDetector?.stop()
        }
        keyEventMonitor?.stop()
        candidateBoxDetector?.stop()
    }

    // MARK: - 服务设置
    private func startCoreServicesIfPermitted() {
        guard PermissionsHelper.isAccessibilityEnabled() else { return }
        guard !servicesStarted else { return }

        servicesStarted = true
        appState.applyRuntimeConfiguration()

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

    private func startPermissionMonitoring() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshAccessibilityPermission()
            }
        }
        refreshAccessibilityPermission()
    }

    private func refreshAccessibilityPermission() {
        let granted = PermissionsHelper.isAccessibilityEnabled()
        guard appState.accessibilityPermissionGranted != granted else { return }

        appState.accessibilityPermissionGranted = granted
        if granted {
            logInfo("辅助功能权限已授权")
            startCoreServicesIfPermitted()
        } else {
            logWarning("辅助功能权限已撤销")
        }
    }

    // MARK: - UI 设置
    private func setupMenuBar() {
        menuBarController = MenuBarController(
            appState: appState,
            onOpenSettings: { [weak self] in self?.openSettings() },
            onQuit: { NSApp.terminate(nil) }
        )
    }

    private func setupRemainingUI() {
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
