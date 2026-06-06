import AppKit

/// 菜单栏控制器 — 原生 NSStatusItem + NSMenu
@MainActor
final class MenuBarController {
    private var statusItem: NSStatusItem?

    private let onOpenSettings: () -> Void
    private let onQuit: () -> Void

    init(
        onOpenSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit

        setupMenuBar()
    }

    // MARK: - 设置
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else { return }

        button.toolTip = "TypeBack"
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        if let image = NSImage(systemSymbolName: "character.cursor.ibeam", accessibilityDescription: "TypeBack") {
            button.image = image.withSymbolConfiguration(config)
            button.image?.isTemplate = true
            button.title = ""
        } else {
            button.title = "TB"
            button.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        }

        statusItem?.menu = makeMenu()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(
            title: "设置...",
            action: #selector(handleOpenSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(
            title: "关于 TypeBack",
            action: #selector(handleAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "退出 TypeBack",
            action: #selector(handleQuit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    // MARK: - 动作
    @objc private func handleOpenSettings() {
        onOpenSettings()
    }

    @objc private func handleAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "TypeBack",
            .credits: NSAttributedString(
                string: "macOS 输入法状态指示与自动回切工具\n\n固定应用身份：com.typeback.app",
                attributes: [.font: NSFont.systemFont(ofSize: 11)]
            )
        ])
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func handleQuit() {
        onQuit()
    }
}
