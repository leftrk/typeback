import SwiftUI

/// 设置窗口 — 使用系统 Form 风格，保持朴素原生。
struct SettingsView: View {
    @Bindable var appState: AppState
    let startRecording: ShortcutRecorderView.StartRecording
    let stopRecording: ShortcutRecorderView.StopRecording

    var body: some View {
        Form {
            permissionSection
            autoSwitchSection
            shortcutSection
            capsLockSection
            launchAtLoginSection
        }
        .padding(20)
        .frame(width: 440, height: 380)
    }

    // MARK: - Sections

    @ViewBuilder
    private var permissionSection: some View {
        if !appState.accessibilityPermissionGranted {
            Section("权限") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("需要辅助功能权限")
                    }

                    Text("授权后 TypeBack 会自动开始监听键盘，不需要重启应用。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("打开辅助功能设置") {
                        PermissionsHelper.requestAccessibilityPermissionPrompt()
                        PermissionsHelper.openAccessibilitySettings()
                    }
                    .controlSize(.small)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var autoSwitchSection: some View {
        Section("自动回切") {
            Toggle("启用自动回切", isOn: $appState.autoSwitchEnabled)

            HStack {
                Text("停止输入后")
                Spacer(minLength: 12)
                TimeoutSecondsField(
                    seconds: Binding(
                        get: { appState.timeoutSeconds },
                        set: { appState.saveTimeout($0) }
                    )
                )
                .disabled(!appState.autoSwitchEnabled)
            }

            Text("关闭后不再自动回切，仅靠快捷键切回英文。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var shortcutSection: some View {
        Section("快捷键") {
            HStack {
                Text("立即回英文")
                Spacer(minLength: 12)
                ShortcutRecorderView(
                    shortcut: $appState.shortcut,
                    startRecording: startRecording,
                    stopRecording: stopRecording
                )
            }
        }
    }

    private var capsLockSection: some View {
        Section("Caps Lock") {
            Toggle("仅切换输入法", isOn: $appState.disableCapsLock)

            Text("打开后长按 Caps Lock 不再锁定大写，短按仍由系统切换输入法。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var launchAtLoginSection: some View {
        Section {
            Toggle("开机自启动", isOn: $appState.launchAtLogin)
        }
    }
}

// MARK: - 超时秒数输入

private struct TimeoutSecondsField: View {
    @Binding var seconds: Int

    private let minSeconds = 5
    private let maxSeconds = 3600

    var body: some View {
        HStack(spacing: 6) {
            TextField("", value: Binding(
                get: { seconds },
                set: { seconds = clamp($0) }
            ), format: .number)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 58)

            Text("秒")
                .foregroundStyle(.secondary)

            Stepper("", value: Binding(
                get: { seconds },
                set: { seconds = clamp($0) }
            ), in: minSeconds...maxSeconds, step: 5)
                .labelsHidden()
        }
    }

    private func clamp(_ value: Int) -> Int {
        max(minSeconds, min(maxSeconds, value))
    }
}
