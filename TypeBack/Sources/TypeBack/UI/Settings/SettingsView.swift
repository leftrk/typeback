import SwiftUI

/// 设置窗口 — 左对齐自定义布局
struct SettingsView: View {
    @Bindable var appState: AppState

    private let timeoutOptions = [30, 60, 120]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "keyboard")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("TypeBack")
                        .font(.headline)
                    Text("输入法自动回切")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 20)

            Divider()

            settingRow {
                Picker("超时时间", selection: Binding(
                    get: { appState.timeoutSeconds },
                    set: { appState.saveTimeout($0) }
                )) {
                    ForEach(timeoutOptions, id: \.self) { seconds in
                        Text("\(seconds) 秒").tag(seconds)
                    }
                }
                .fixedSize()
            } caption: {
                Text("停止中文输入后，等待该时长自动切回英文。")
            }

            Divider()

            settingRow {
                Toggle("禁用 Caps Lock 大写锁定", isOn: $appState.disableCapsLock)
            } caption: {
                Text("仅保留切换输入法功能，彻底禁用长按锁定大写。")
            }

            Divider()

            settingRow {
                Toggle("开机自启动", isOn: $appState.launchAtLogin)
            }
        }
        .padding(24)
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func settingRow<C: View>(
        @ViewBuilder content: () -> C,
        caption: (() -> Text)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
            if let caption {
                caption()
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 12)
    }
}
