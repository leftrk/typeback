import AppKit
import SwiftUI

/// 设置窗口控制器 — 直接管理 NSWindow，适配 menu bar app
@MainActor
final class SettingsController {
    private var window: NSWindow?
    private var closeObserver: NSObjectProtocol?
    private let appState: AppState
    private let startRecording: ShortcutRecorderView.StartRecording
    private let stopRecording: ShortcutRecorderView.StopRecording

    init(
        appState: AppState,
        startRecording: @escaping ShortcutRecorderView.StartRecording,
        stopRecording: @escaping ShortcutRecorderView.StopRecording
    ) {
        self.appState = appState
        self.startRecording = startRecording
        self.stopRecording = stopRecording
    }

    func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let w = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "TypeBack 设置"
        w.isReleasedWhenClosed = false

        let view = SettingsView(
            appState: appState,
            startRecording: startRecording,
            stopRecording: stopRecording
        )
        let hostingView = NSHostingView(rootView: view)
        w.contentView = hostingView
        w.setContentSize(hostingView.fittingSize)
        w.center()

        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: w,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.window = nil
                if let obs = self?.closeObserver {
                    NotificationCenter.default.removeObserver(obs)
                }
                self?.closeObserver = nil
            }
        }

        window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
