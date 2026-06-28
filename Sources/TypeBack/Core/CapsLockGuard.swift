import AppKit
import CoreGraphics
import IOKit
import IOKit.hid

/// 拦截 Caps Lock 大写锁定激活，剥离 capsLock 标志位并重置硬件状态，
/// 保留短按切换输入法的功能，仅禁用长按锁定大写。
final class CapsLockGuard: @unchecked Sendable {
    private static let capsLockFlag: UInt64 = 0x00010000

    private static let eventMask: CGEventMask =
        (1 << CGEventType.flagsChanged.rawValue) |
        (1 << CGEventType.keyDown.rawValue) |
        (1 << CGEventType.keyUp.rawValue)

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    deinit { stop() }

    func start() -> Bool {
        guard AXIsProcessTrusted() else { return false }
        guard eventTap == nil else { return true }
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

    private func createEventTap() -> Bool {
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon = refcon else {
                return Unmanaged.passUnretained(event)
            }

            let self_ = Unmanaged<CapsLockGuard>.fromOpaque(refcon).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = self_.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            let flags = event.flags.rawValue
            if flags & CapsLockGuard.capsLockFlag != 0 {
                event.flags = CGEventFlags(rawValue: flags & ~CapsLockGuard.capsLockFlag)
                if type == .flagsChanged {
                    CapsLockGuard.resetCapsLockHardwareState()
                }
            }

            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: Self.eventMask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        eventTap = tap

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            eventTap = nil
            return false
        }

        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    /// 通过 IOKit 重置 Caps Lock 硬件状态，关闭键盘 LED 指示灯
    private static func resetCapsLockHardwareState() {
        let service = IOServiceGetMatchingService(0, IOServiceMatching("IOHIDSystem"))
        guard service != IO_OBJECT_NULL else { return }
        defer { IOObjectRelease(service) }

        var connection: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, 1, &connection) == KERN_SUCCESS else { return }
        defer { IOServiceClose(connection) }

        IOHIDSetModifierLockState(connection, 1, false)
    }
}
