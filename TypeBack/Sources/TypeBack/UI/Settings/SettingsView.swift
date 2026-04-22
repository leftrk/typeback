import SwiftUI

/// 设置窗口 — macOS 原生风格
struct SettingsView: View {
    @Bindable var appState: AppState

    private let timeoutOptions = [30, 60, 120]

    var body: some View {
        Form {
            Section {
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
                .padding(.vertical, 4)
            }

            Section {
                Picker("超时时间", selection: Binding(
                    get: { appState.timeoutSeconds },
                    set: { appState.saveTimeout($0) }
                )) {
                    ForEach(timeoutOptions, id: \.self) { seconds in
                        Text("\(seconds) 秒").tag(seconds)
                    }
                }
            } footer: {
                Text("停止中文输入后，等待该时长自动切回英文。")
            }

            Section {
                Toggle("开机自启动", isOn: $appState.launchAtLogin)
            }
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
    }
}
