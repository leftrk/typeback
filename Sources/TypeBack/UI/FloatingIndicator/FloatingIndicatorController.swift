import AppKit
import SwiftUI

/// 浮动指示器控制器 — 支持拖动，位置持久化
@MainActor
final class FloatingIndicatorController {
    private var window: NSPanel?
    private var hostingView: NSHostingView<IndicatorView>?

    private let windowSize = CGSize(width: 46, height: 46)
    private let appState: AppState
    private var savedPosition: CGPoint?
    private var observationTask: Task<Void, Never>?
    private var moveObserver: NSObjectProtocol?

    init(appState: AppState) {
        self.appState = appState
        self.savedPosition = appState.loadIndicatorPosition()
    }

    deinit {
        observationTask?.cancel()
        if let obs = moveObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    func show() {
        createWindow()
        window?.makeKeyAndOrderFront(nil)
        startObservation()
    }

    func hide() {
        window?.orderOut(nil)
        observationTask?.cancel()
    }

    func flash() {
        guard let window = window else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            window.animator().alphaValue = 0.3
        } completionHandler: {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.1
                window.animator().alphaValue = 1.0
            }
        }
    }

    // MARK: - 观察
    private func startObservation() {
        observationTask = Task { [weak self] in
            var lastState: InputState = .english
            while !Task.isCancelled {
                guard let self = self else { break }
                if self.appState.currentInputState != lastState {
                    lastState = self.appState.currentInputState
                    if lastState == .english {
                        await MainActor.run { self.flash() }
                    }
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    // MARK: - 创建窗口
    private func createWindow() {
        let origin = savedPosition ?? defaultPosition

        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hasShadow = false
        panel.backgroundColor = .clear
        panel.isMovableByWindowBackground = true
        panel.isMovable = true
        panel.isRestorable = false

        let contentView = IndicatorView(
            appState: appState,
            onTap: { NotificationCenter.default.post(name: .toggleInputMethod, object: nil) },
            onDoubleTap: { NotificationCenter.default.post(name: .openSettings, object: nil) }
        )

        hostingView = NSHostingView(rootView: contentView)
        hostingView?.frame = NSRect(origin: .zero, size: windowSize)
        panel.contentView = hostingView

        window = panel

        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let w = self.window else { return }
                let origin = w.frame.origin
                self.savedPosition = origin
                self.appState.saveIndicatorPosition(origin)
            }
        }
    }

    /// 默认位置：屏幕右侧三分之一、垂直居中
    private var defaultPosition: CGPoint {
        guard let screen = NSScreen.main else { return CGPoint(x: 200, y: 200) }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.origin.x + screenFrame.width * 2 / 3
        let y = screenFrame.origin.y + screenFrame.height / 2 - windowSize.height / 2
        return CGPoint(x: x, y: y)
    }
}

// MARK: - 通知扩展
extension Notification.Name {
    static let openSettings = Notification.Name("TypeBack.openSettings")
    static let toggleInputMethod = Notification.Name("TypeBack.toggleInputMethod")
}
