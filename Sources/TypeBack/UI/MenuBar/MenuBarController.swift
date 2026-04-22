import AppKit
import SwiftUI

/// 菜单栏控制器 — SF Symbol 图标 + 精简下拉菜单
@MainActor
final class MenuBarController {
    private var statusItem: NSStatusItem?
    private let appState: AppState

    private let onOpenSettings: () -> Void
    private let onSwitchToEnglish: () -> Void
    private let onQuit: () -> Void

    private var observationTask: Task<Void, Never>?

    init(
        appState: AppState,
        onOpenSettings: @escaping () -> Void,
        onSwitchToEnglish: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.appState = appState
        self.onOpenSettings = onOpenSettings
        self.onSwitchToEnglish = onSwitchToEnglish
        self.onQuit = onQuit

        setupMenuBar()
        startObservation()
    }

    deinit {
        observationTask?.cancel()
    }

    // MARK: - 设置
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            if let image = NSImage(systemSymbolName: "character.cursor.ibeam", accessibilityDescription: "TypeBack") {
                button.image = image.withSymbolConfiguration(config)
                button.image?.isTemplate = true
            }
        }

        updateMenu()
    }

    // MARK: - 状态观察
    private func startObservation() {
        observationTask = Task { [weak self] in
            var lastState: InputState = .english
            var lastCountdown: Int = 0

            while !Task.isCancelled {
                guard let self = self else { break }

                if self.appState.currentInputState != lastState ||
                   self.appState.countdownSeconds != lastCountdown {
                    lastState = self.appState.currentInputState
                    lastCountdown = self.appState.countdownSeconds

                    await MainActor.run {
                        self.updateMenu()
                    }
                }

                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }

    private func updateMenu() {
        let menu = NSMenu()

        let statusItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        if appState.isChinese {
            let switchItem = NSMenuItem(
                title: "立即切回英文",
                action: #selector(handleSwitchToEnglish),
                keyEquivalent: ""
            )
            switchItem.target = self
            menu.addItem(switchItem)
        }

        let settingsItem = NSMenuItem(
            title: "设置...",
            action: #selector(handleOpenSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "退出 TypeBack",
            action: #selector(handleQuit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem?.menu = menu
    }

    private var statusText: String {
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

    @objc private func handleSwitchToEnglish() {
        onSwitchToEnglish()
    }

    @objc private func handleQuit() {
        onQuit()
    }
}
