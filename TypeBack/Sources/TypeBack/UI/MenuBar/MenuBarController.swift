import AppKit
import SwiftUI
import Sparkle

/// 菜单栏控制器 — SF Symbol 图标 + 精简下拉菜单
@MainActor
final class MenuBarController {
    private static let statusItemAutosaveName = "com.huaguan.typeback.statusItem"

    private var statusItem: NSStatusItem?
    private var fallbackPanel: NSPanel?
    private var fallbackButton: NSButton?
    private let appState: AppState
    private let updater: SPUUpdater?

    private let onOpenSettings: () -> Void
    private let onQuit: () -> Void

    private var observationTask: Task<Void, Never>?

    init(
        appState: AppState,
        updater: SPUUpdater?,
        onOpenSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.appState = appState
        self.updater = updater
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit

        setupMenuBar()
        setupFallbackControlIfNeeded()
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
        statusItem?.autosaveName = Self.statusItemAutosaveName

        if let button = statusItem?.button {
            button.toolTip = "TypeBack"
            button.image = nil
            button.title = "TB"
            button.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        }

        statusItem?.menu = makeMenu()
    }

    private func setupFallbackControlIfNeeded() {
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26 else { return }
        guard fallbackPanel == nil else { return }
        guard let screen = NSScreen.main else { return }

        let size = NSSize(width: 38, height: 24)
        let visibleFrame = screen.visibleFrame
        let origin = NSPoint(
            x: visibleFrame.maxX - size.width - 10,
            y: visibleFrame.maxY - size.height + 1
        )

        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isOpaque = false
        panel.isMovable = false
        panel.isRestorable = false

        let button = NSButton(frame: NSRect(origin: .zero, size: size))
        button.title = "TB"
        button.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        button.bezelStyle = .rounded
        button.isBordered = true
        button.target = self
        button.action = #selector(handleFallbackMenu)
        button.toolTip = "TypeBack"

        panel.contentView = button
        fallbackPanel = panel
        fallbackButton = button
        panel.orderFrontRegardless()
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

        // 检查更新
        if updater != nil {
            let updateItem = NSMenuItem(
                title: "检查更新...",
                action: #selector(handleCheckForUpdates),
                keyEquivalent: ""
            )
            updateItem.target = self
            menu.addItem(updateItem)
        }

        menu.addItem(NSMenuItem.separator())

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

    @objc private func handleFallbackMenu() {
        guard let button = fallbackButton else { return }
        let menu = makeMenu()
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func handleCheckForUpdates() {
        updater?.checkForUpdates()
    }

    @objc private func handleQuit() {
        onQuit()
    }
}
