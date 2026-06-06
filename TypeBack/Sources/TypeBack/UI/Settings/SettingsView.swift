import SwiftUI

/// 设置窗口 — 朴素原生控件布局，避免 macOS Form 自动两列裁切。
struct SettingsView: View {
    @Bindable var appState: AppState
    let startRecording: ShortcutRecorderView.StartRecording
    let stopRecording: ShortcutRecorderView.StopRecording

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            permissionSection
            autoSwitchSection
            shortcutSection
            capsLockSection
            launchAtLoginSection
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(width: 460, height: 360)
    }

    // MARK: - Sections

    @ViewBuilder
    private var permissionSection: some View {
        if !appState.accessibilityPermissionGranted {
            SettingsGroup("权限") {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("需要辅助功能权限")

                    Spacer()

                    Button("打开辅助功能设置") {
                        PermissionsHelper.requestAccessibilityPermissionPrompt()
                        PermissionsHelper.openAccessibilitySettings()
                    }
                    .controlSize(.small)
                }

                helpText("授权后 TypeBack 会自动开始监听键盘，不需要重启应用。")
            }
        }
    }

    private var autoSwitchSection: some View {
        SettingsGroup("自动回切") {
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

            helpText("关闭后不再自动回切，仅靠快捷键切回英文。")
        }
    }

    private var shortcutSection: some View {
        SettingsGroup("快捷键") {
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
        SettingsGroup("Caps Lock") {
            Toggle("仅切换输入法", isOn: $appState.disableCapsLock)

            helpText("打开后长按 Caps Lock 不再锁定大写，短按仍由系统切换输入法。")
        }
    }

    private var launchAtLoginSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("开机自启动", isOn: $appState.launchAtLogin)
        }
    }

    private func helpText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
