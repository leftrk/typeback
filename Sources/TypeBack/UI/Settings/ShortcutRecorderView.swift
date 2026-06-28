import AppKit
import Carbon
import SwiftUI

/// 设置面板里录制「立即回英文」快捷键的组件
///
/// 录制走全局 CGEventTap（由 KeyEventMonitor 提供），这样即便用户按下当前已配置的
/// 快捷键也不会被原回调拦截，且不依赖窗口焦点状态。
struct ShortcutRecorderView: View {
    typealias StartRecording = (@escaping @Sendable (UInt16, UInt) -> Void) -> Void
    typealias StopRecording = () -> Void

    @Binding var shortcut: Shortcut
    let startRecording: StartRecording
    let stopRecording: StopRecording

    @State private var isRecording = false

    var body: some View {
        HStack(spacing: 8) {
            shortcutChip
            recordButton
        }
        .onDisappear {
            if isRecording {
                stopRecording()
            }
        }
    }

    private var shortcutChip: some View {
        Text(isRecording ? "请按下组合键…" : shortcut.displayString)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(isRecording ? .secondary : .primary)
            .frame(minWidth: 110, alignment: .center)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.background.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isRecording
                            ? Color.accentColor
                            : Color.secondary.opacity(0.25),
                        lineWidth: 1
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: isRecording)
    }

    private var recordButton: some View {
        Button(isRecording ? "取消" : "录制") {
            if isRecording {
                cancelRecording()
            } else {
                beginRecording()
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func beginRecording() {
        isRecording = true
        startRecording { keyCode, modifiers in
            Task { @MainActor in
                handle(keyCode: keyCode, modifiers: modifiers)
            }
        }
    }

    private func cancelRecording() {
        stopRecording()
        isRecording = false
    }

    private func handle(keyCode: UInt16, modifiers: UInt) {
        let mask = NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue
        let masked = modifiers & mask
        let mods = NSEvent.ModifierFlags(rawValue: masked)

        // ESC 单独按下（无修饰键）视为取消
        if Int(keyCode) == kVK_Escape
            && mods.intersection([.control, .shift, .option, .command]).isEmpty {
            cancelRecording()
            return
        }

        let candidate = Shortcut(keyCode: keyCode, modifiers: masked)
        guard candidate.isValid else {
            // 没有修饰键，提示音并继续等待下一次按键
            NSSound.beep()
            return
        }

        shortcut = candidate
        stopRecording()
        isRecording = false
    }
}
