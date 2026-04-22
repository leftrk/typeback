import SwiftUI
import ServiceManagement

@Observable
@MainActor
final class AppState {
    // MARK: - 状态
    var currentInputState: InputState = .english
    var countdownSeconds: Int = 0
    var timeoutSeconds: Int = 60

    // MARK: - 配置
    var launchAtLogin: Bool = false {
        didSet { updateLaunchAtLogin() }
    }

    var disableCapsLock: Bool = false {
        didSet { updateCapsLockGuard() }
    }

    private var capsLockGuard: CapsLockGuard?

    private let userDefaults = UserDefaults.standard
    private let timeoutKey = "timeoutSeconds"
    private let launchAtLoginKey = "launchAtLogin"
    private let disableCapsLockKey = "disableCapsLock"
    private let positionKey = "indicatorPosition"

    // MARK: - 计算属性
    var isEnglish: Bool { currentInputState == .english }
    var isChinese: Bool { !isEnglish }

    var displayText: String {
        switch currentInputState {
        case .english: return "EN"
        case .chineseIdle, .chineseTyping, .chineseCountdown: return "CN"
        }
    }

    // MARK: - 初始化
    init() {
        loadSettings()
    }

    // MARK: - 状态转换
    func setTyping() {
        guard isChinese else { return }
        currentInputState = .chineseTyping
        countdownSeconds = 0
    }

    func setIdle() {
        guard isChinese else { return }
        currentInputState = .chineseIdle
    }

    func setCountdown(_ seconds: Int) {
        guard isChinese else { return }
        currentInputState = .chineseCountdown
        countdownSeconds = seconds
    }

    func setEnglish() {
        guard !isEnglish else { return }
        currentInputState = .english
        countdownSeconds = 0
    }

    func setChinese() {
        guard isEnglish else { return }
        currentInputState = .chineseIdle
    }

    // MARK: - 设置管理
    private func loadSettings() {
        let saved = userDefaults.integer(forKey: timeoutKey)
        timeoutSeconds = saved > 0 ? saved : 60
        launchAtLogin = userDefaults.bool(forKey: launchAtLoginKey)
        disableCapsLock = userDefaults.bool(forKey: disableCapsLockKey)
    }

    func saveTimeout(_ seconds: Int) {
        timeoutSeconds = seconds
        userDefaults.set(seconds, forKey: timeoutKey)
    }

    private func updateCapsLockGuard() {
        userDefaults.set(disableCapsLock, forKey: disableCapsLockKey)
        if disableCapsLock {
            if capsLockGuard == nil {
                capsLockGuard = CapsLockGuard()
            }
            let started = capsLockGuard?.start() ?? false
            logInfo("Caps Lock 防误触 \(started ? "已启动" : "启动失败")")
        } else {
            capsLockGuard?.stop()
            capsLockGuard = nil
        }
    }

    private func updateLaunchAtLogin() {
        userDefaults.set(launchAtLogin, forKey: launchAtLoginKey)
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            logWarning("设置开机自启动失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 指示器位置持久化
    func loadIndicatorPosition() -> CGPoint? {
        guard let data = userDefaults.data(forKey: positionKey),
              let point = try? JSONDecoder().decode(CGPoint.self, from: data) else {
            return nil
        }
        return point
    }

    func saveIndicatorPosition(_ point: CGPoint) {
        if let data = try? JSONEncoder().encode(point) {
            userDefaults.set(data, forKey: positionKey)
        }
    }
}
