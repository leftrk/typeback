import AppKit
import Carbon
import SwiftUI

// MARK: - 输入状态
enum InputState: Equatable {
    case english
    case chineseIdle
    case chineseTyping
    case chineseCountdown
}

// MARK: - 快捷键

/// 「立即回英文」快捷键。modifiers 沿用 NSEvent.ModifierFlags rawValue，与 CGEventFlags 的修饰位 bit 一致。
struct Shortcut: Codable, Equatable, Sendable {
    var keyCode: UInt16
    var modifiers: UInt

    static let `default` = Shortcut(
        keyCode: UInt16(kVK_Space),
        modifiers: NSEvent.ModifierFlags.control.rawValue
    )

    /// 校验：必须至少含一个修饰键（避免单键误触发）
    var isValid: Bool {
        let mask: UInt = NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue
        let mods = NSEvent.ModifierFlags(rawValue: modifiers & mask)
        return !mods.intersection([.control, .shift, .option, .command]).isEmpty
    }

    /// 人类可读字符串，如 "⌃Space"
    var displayString: String {
        let mods = NSEvent.ModifierFlags(rawValue: modifiers)
        var parts = ""
        if mods.contains(.control) { parts += "⌃" }
        if mods.contains(.option) { parts += "⌥" }
        if mods.contains(.shift) { parts += "⇧" }
        if mods.contains(.command) { parts += "⌘" }
        parts += KeyCodeNames.name(for: keyCode)
        return parts
    }
}

// MARK: - KeyCode 显示

enum KeyCodeNames {
    static func name(for keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Escape: return "Esc"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default:
            // 字母/数字键查询 layout
            if let s = characterFromKeyCode(keyCode) { return s.uppercased() }
            return "Key\(keyCode)"
        }
    }

    private static func characterFromKeyCode(_ keyCode: UInt16) -> String? {
        guard let layout = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutDataPtr = TISGetInputSourceProperty(layout, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let layoutData = Unmanaged<CFData>.fromOpaque(layoutDataPtr).takeUnretainedValue() as Data

        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0

        let status = layoutData.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> OSStatus in
            guard let ptr = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                return -1
            }
            return UCKeyTranslate(
                ptr,
                keyCode,
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &length,
                &chars
            )
        }

        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }
}
