import Foundation

/// 输入状态（用于回调）
enum TypingState: Sendable {
    case typing
    case idle
    case countdown(Int)
    case timeout
}

/// 输入状态检测器 - 优化版
/// 使用更精确的定时器管理，避免内存泄漏
actor TypingStateDetector {

    // MARK: - 配置
    private let typingEndDelay: TimeInterval
    private let onStateChanged: @Sendable (TypingState) -> Void

    // MARK: - 状态
    private var typingEndTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?
    private var remainingSeconds: Int = 0
    private var isTyping: Bool = false
    private var isActive: Bool = false

    // MARK: - 初始化
    init(typingEndDelay: TimeInterval = 2.0, onStateChanged: @escaping @Sendable (TypingState) -> Void) {
        self.typingEndDelay = typingEndDelay
        self.onStateChanged = onStateChanged
    }

    // MARK: - 生命周期
    func start() {
        isActive = true
    }

    func stop() {
        isActive = false
        cancelAllTasks()
    }

    // MARK: - 用户输入检测
    func resetTyping() {
        guard isActive else { return }

        isTyping = true
        cancelCountdownTask()

        // 使用 Task 替代 Timer，避免 RunLoop 依赖
        typingEndTask?.cancel()
        typingEndTask = Task { [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(nanoseconds: UInt64(self.typingEndDelay * 1_000_000_000))
            await self.typingEnded()
        }

        onStateChanged(.typing)
    }

    // MARK: - 倒计时管理
    func startCountdown(seconds: Int) {
        guard isActive else { return }

        remainingSeconds = seconds
        cancelCountdownTask()

        countdownTask = Task { [weak self] in
            guard let self = self else { return }
            await self.runCountdown()
        }

        onStateChanged(.countdown(remainingSeconds))
    }

    private func runCountdown() async {
        while remainingSeconds > 0 {
            // 每秒检查一次，但允许被取消
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            guard !Task.isCancelled else { return }

            remainingSeconds -= 1

            if remainingSeconds > 0 {
                onStateChanged(.countdown(remainingSeconds))
            }
        }

        if !Task.isCancelled {
            onStateChanged(.timeout)
        }
    }

    // MARK: - 私有方法
    private func typingEnded() {
        guard isActive, isTyping else { return }
        isTyping = false
        onStateChanged(.idle)
    }

    private func cancelAllTasks() {
        typingEndTask?.cancel()
        typingEndTask = nil
        countdownTask?.cancel()
        countdownTask = nil
    }

    private func cancelCountdownTask() {
        countdownTask?.cancel()
        countdownTask = nil
    }
}
