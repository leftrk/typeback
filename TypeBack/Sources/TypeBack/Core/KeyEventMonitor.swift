import Carbon
import AppKit
import Foundation
import CoreGraphics
import os

/// 键盘事件监听器
/// 使用 CGEventTap 实现全局键盘监听，匹配用户配置的快捷键时立即触发回调
final class KeyEventMonitor: @unchecked Sendable {
    private static let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
    private static let modifierMask: CGEventFlags = [
        .maskControl, .maskShift, .maskAlternate, .maskCommand
    ]

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private let onKeyEvent: @Sendable () -> Void
    private let onShortcut: @Sendable () -> Void

    /// 配置的快捷键，可在运行时通过 updateShortcut 修改
    private let shortcutLock = OSAllocatedUnfairLock<ShortcutValue>(
        initialState: ShortcutValue.default
    )

    /// 录制态投喂器：非 nil 时，所有 keyDown 都会被消费并投喂给此回调，不再匹配快捷键
    private let recordingLock = OSAllocatedUnfairLock<(@Sendable (UInt16, UInt) -> Void)?>(
        initialState: nil
    )

    private struct ShortcutValue: Sendable {
        var keyCode: Int64
        var modifiers: CGEventFlags

        static let `default` = ShortcutValue(
            keyCode: Int64(kVK_Space),
            modifiers: .maskControl
        )
    }

    init(
        shortcut: Shortcut = .default,
        onKeyEvent: @escaping @Sendable () -> Void,
        onShortcut: @escaping @Sendable () -> Void
    ) {
        self.onKeyEvent = onKeyEvent
        self.onShortcut = onShortcut
        self.shortcutLock.withLock { state in
            state.keyCode = Int64(shortcut.keyCode)
            state.modifiers = CGEventFlags(rawValue: UInt64(shortcut.modifiers))
                .intersection(Self.modifierMask)
        }
    }

    deinit {
        stop()
    }

    // MARK: - 生命周期

    func start() -> Bool {
        guard checkAccessibilityPermission() else {
            print("KeyEventMonitor: 需要辅助功能权限")
            return false
        }

        guard eventTap == nil else {
            return true
        }

        return createEventTap()
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    func updateShortcut(_ shortcut: Shortcut) {
        shortcutLock.withLock { state in
            state.keyCode = Int64(shortcut.keyCode)
            state.modifiers = CGEventFlags(rawValue: UInt64(shortcut.modifiers))
                .intersection(Self.modifierMask)
        }
    }

    /// 开始录制：在收到任何 keyDown 时调用 handler，并消费事件不传递给系统/前台应用
    func startRecording(handler: @escaping @Sendable (UInt16, UInt) -> Void) {
        recordingLock.withLock { $0 = handler }
    }

    func stopRecording() {
        recordingLock.withLock { $0 = nil }
    }

    // MARK: - 私有方法

    private func checkAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    private func createEventTap() -> Bool {
        let callback: CGEventTapCallBack = { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
            guard let refcon = refcon else {
                return Unmanaged.passUnretained(event)
            }

            let monitor = Unmanaged<KeyEventMonitor>.fromOpaque(refcon).takeUnretainedValue()
            return monitor.handleEvent(proxy: proxy, type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: Self.eventMask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("KeyEventMonitor: 创建事件监听失败")
            return false
        }

        eventTap = tap

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            print("KeyEventMonitor: 创建 RunLoop Source 失败")
            eventTap = nil
            return false
        }

        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        return true
    }

    private func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        // 系统会在 tap 响应慢时自动禁用，必须重新启用
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags.intersection(Self.modifierMask)

        // 录制态：所有 keyDown 都投喂给录制器，并消费（绕过快捷键匹配）
        if let recordHandler = recordingLock.withLock({ $0 }) {
            let kc = UInt16(keyCode)
            let mods = UInt(flags.rawValue)
            DispatchQueue.main.async { recordHandler(kc, mods) }
            return nil
        }

        let target = shortcutLock.withLock { $0 }
        if keyCode == target.keyCode && flags == target.modifiers {
            DispatchQueue.main.async { [weak self] in self?.onShortcut() }
            return nil  // 消费事件，防止系统也响应
        }
        DispatchQueue.main.async { [weak self] in self?.onKeyEvent() }
        return Unmanaged.passUnretained(event)
    }
}

// MARK: - CGEventTapLocation 扩展

private extension CGEventTapLocation {
    static let cgSessionEventTap = CGEventTapLocation(rawValue: 1)
    static let headInsertEventTap = CGEventTapPlacement(rawValue: 0)
}
