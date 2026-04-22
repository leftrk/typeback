import Carbon
import AppKit
import Foundation
import CoreGraphics

/// 键盘事件监听器
/// 使用 CGEventTap 实现全局键盘监听，单击 ESC 立即触发回调
final class KeyEventMonitor: @unchecked Sendable {
    private static let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private let onKeyEvent: @Sendable () -> Void
    private let onEsc: @Sendable () -> Void

    init(
        onKeyEvent: @escaping @Sendable () -> Void,
        onEsc: @escaping @Sendable () -> Void
    ) {
        self.onKeyEvent = onKeyEvent
        self.onEsc = onEsc
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

    // MARK: - 私有方法

    private func checkAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    private func createEventTap() -> Bool {
        let callback: CGEventTapCallBack = { (proxy, type, event, refcon) in
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
    ) -> Unmanaged<CGEvent> {
        DispatchQueue.main.async { [weak self] in
            self?.processKeyEvent(event)
        }
        // 事件始终穿透给前台应用
        return Unmanaged.passUnretained(event)
    }

    private func processKeyEvent(_ event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        if keyCode == Int64(kVK_Escape) {
            onEsc()
        } else {
            onKeyEvent()
        }
    }
}

// MARK: - CGEventTapLocation 扩展

private extension CGEventTapLocation {
    static let cgSessionEventTap = CGEventTapLocation(rawValue: 1)
    static let headInsertEventTap = CGEventTapPlacement(rawValue: 0)
}
