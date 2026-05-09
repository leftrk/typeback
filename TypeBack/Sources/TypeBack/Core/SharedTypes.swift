import SwiftUI

// MARK: - 输入状态
enum InputState: Equatable {
    case english
    case chineseIdle
    case chineseTyping
    case chineseCountdown
}

// MARK: - 快捷键模式
enum HotKeyMode: String, CaseIterable {
    case doubleEsc = "doubleEsc"
    case ctrlSpace = "ctrlSpace"

    var displayName: String {
        switch self {
        case .doubleEsc: return "ESC × 2"
        case .ctrlSpace: return "⌃Space"
        }
    }
}
