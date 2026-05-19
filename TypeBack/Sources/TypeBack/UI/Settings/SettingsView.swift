import SwiftUI

/// 设置窗口 — 卡片化布局，与指示器风格统一
struct SettingsView: View {
    @Bindable var appState: AppState
    let startRecording: ShortcutRecorderView.StartRecording
    let stopRecording: ShortcutRecorderView.StopRecording

    var body: some View {
        VStack(spacing: 14) {
            heroSection
            autoSwitchCard
            shortcutCard
            capsLockCard
            launchAtLoginCard
        }
        .padding(20)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 10) {
            // 活的迷你指示器：实时同步当前输入法状态（小尺寸，不参与水波）
            ProgressRingIndicator(appState: appState, containerSize: 76)
                .allowsHitTesting(false)

            VStack(spacing: 2) {
                Text("TypeBack")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Text("输入法状态与自动回切")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity)
    }

    // MARK: - 卡片

    private var autoSwitchCard: some View {
        SettingCard(title: "自动回切", caption: "关闭后不再自动回切，仅靠快捷键切回英文。") {
            settingRow("启用自动回切") {
                Toggle("", isOn: $appState.autoSwitchEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            settingRow("停止输入后") {
                TimeoutSecondsField(
                    seconds: Binding(
                        get: { appState.timeoutSeconds },
                        set: { appState.saveTimeout($0) }
                    )
                )
                .disabled(!appState.autoSwitchEnabled)
            }
        }
    }

    private var shortcutCard: some View {
        SettingCard(title: "快捷键") {
            settingRow("立即回英文") {
                ShortcutRecorderView(
                    shortcut: $appState.shortcut,
                    startRecording: startRecording,
                    stopRecording: stopRecording
                )
            }
        }
    }

    private var capsLockCard: some View {
        SettingCard(title: "Caps Lock", caption: "打开后 Caps Lock 不再锁定大写，仅用于切换输入法。") {
            settingRow("仅切换输入法") {
                Toggle("", isOn: $appState.disableCapsLock)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
        }
    }

    private var launchAtLoginCard: some View {
        SettingCard(title: nil) {
            settingRow("开机自启动") {
                Toggle("", isOn: $appState.launchAtLogin)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
        }
    }

    // MARK: - 行通用样式

    private func settingRow<Trailing: View>(
        _ label: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, design: .rounded))
            Spacer(minLength: 12)
            trailing()
        }
    }
}

// MARK: - 卡片容器

private struct SettingCard<Content: View>: View {
    let title: String?
    let caption: String?
    @ViewBuilder let content: () -> Content

    init(
        title: String?,
        caption: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.caption = caption
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
            }

            VStack(alignment: .leading, spacing: 10) {
                content()
            }

            if let caption {
                Text(caption)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
        )
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
                .font(.system(size: 13, design: .rounded))
                .frame(width: 58)

            Text("秒")
                .font(.system(size: 13, design: .rounded))
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
