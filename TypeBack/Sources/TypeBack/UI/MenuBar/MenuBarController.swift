import AppKit

/// 菜单栏控制器 — 原生 NSStatusItem + NSMenu
@MainActor
final class MenuBarController {
    private var statusItem: NSStatusItem?
    private let appState: AppState

    private let onOpenSettings: () -> Void
    private let onQuit: () -> Void

    private var observationTask: Task<Void, Never>?

    init(
        appState: AppState,
        onOpenSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.appState = appState
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit

        setupMenuBar()
        scheduleVisibilityCheck()
        startObservation()
    }

    deinit {
        observationTask?.cancel()
    }

    // MARK: - 设置
    private func setupMenuBar() {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.isVisible = true

        if let button = statusItem?.button {
            button.isHidden = false
            button.toolTip = "TypeBack"
            button.image = nil
            button.title = "TB"
            button.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
            logInfo("菜单栏按钮已创建: title=\(button.title), width=\(button.frame.width)")
        } else {
            logError("菜单栏按钮创建失败: statusItem.button=nil")
        }

        statusItem?.menu = makeMenu()
    }

    private func scheduleVisibilityCheck() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard let self else { return }

            if self.statusItem?.button == nil {
                logWarning("菜单栏图标不可用，正在重建 NSStatusItem")
                self.setupMenuBar()
            }
        }
    }

    // MARK: - 状态观察
    private func startObservation() {
        observationTask = Task { [weak self] in
            var lastState: InputState = .english
            var lastCountdown: Int = 0
            var lastPermission = true

            while !Task.isCancelled {
                guard let self = self else { break }

                if self.appState.currentInputState != lastState ||
                   self.appState.countdownSeconds != lastCountdown ||
                   self.appState.accessibilityPermissionGranted != lastPermission {
                    lastState = self.appState.currentInputState
                    lastCountdown = self.appState.countdownSeconds
                    lastPermission = self.appState.accessibilityPermissionGranted

                    await MainActor.run {
                        self.updateMenu()
                    }
                }

                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }

    private func updateMenu() {
        statusItem?.menu = makeMenu()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let statusItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        if !appState.accessibilityPermissionGranted {
            let permissionItem = NSMenuItem(
                title: "授权辅助功能权限...",
                action: #selector(handleOpenAccessibilitySettings),
                keyEquivalent: ""
            )
            permissionItem.target = self
            menu.addItem(permissionItem)
        }

        let settingsItem = NSMenuItem(
            title: "设置...",
            action: #selector(handleOpenSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(
            title: "退出 TypeBack",
            action: #selector(handleQuit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private var statusText: String {
        guard appState.accessibilityPermissionGranted else {
            return "需要辅助功能权限"
        }

        switch appState.currentInputState {
        case .english:
            return "当前: 英文"
        case .chineseIdle, .chineseTyping:
            return "当前: 中文"
        case .chineseCountdown:
            return "当前: 中文 (\(appState.countdownSeconds)s)"
        }
    }

    // MARK: - 动作
    @objc private func handleOpenSettings() {
        onOpenSettings()
    }

    @objc private func handleOpenAccessibilitySettings() {
        PermissionsHelper.requestAccessibilityPermissionPrompt()
        PermissionsHelper.openAccessibilitySettings()
    }

    @objc private func handleQuit() {
        onQuit()
    }
}
