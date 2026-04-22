import AppKit
import Foundation

/// 候选框检测器
/// 检测输入法候选窗口是否可见，提供同步查询接口供 ESC 处理使用
final class CandidateBoxDetector: @unchecked Sendable {
    // MARK: - 配置
    private let checkInterval: TimeInterval
    private let onCandidateBoxStateChanged: @Sendable (Bool) -> Void

    // MARK: - 状态
    private var checkTask: Task<Void, Never>?
    private nonisolated(unsafe) var _hasCandidateBox: Bool = false
    private var isRunning: Bool = false
    private let lock = NSLock()

    /// 同步查询当前是否有候选框（线程安全，供 ESC 回调使用）
    var hasCandidateBox: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _hasCandidateBox
    }

    // MARK: - 初始化
    init(
        checkInterval: TimeInterval = 0.2,
        onCandidateBoxStateChanged: @escaping @Sendable (Bool) -> Void
    ) {
        self.checkInterval = checkInterval
        self.onCandidateBoxStateChanged = onCandidateBoxStateChanged
    }

    deinit {
        stop()
    }

    // MARK: - 生命周期
    func start() {
        lock.lock()
        defer { lock.unlock() }

        guard !isRunning else { return }
        isRunning = true

        checkTask = Task { [weak self] in
            guard let self = self else { return }
            await self.runDetectionLoop()
        }
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }

        isRunning = false
        checkTask?.cancel()
        checkTask = nil
    }

    // MARK: - 检测循环
    private func runDetectionLoop() async {
        while isRunning && !Task.isCancelled {
            let hasBox = hasCandidateWindow()

            let changed: Bool = {
                lock.lock()
                defer { lock.unlock() }
                let diff = hasBox != _hasCandidateBox
                _hasCandidateBox = hasBox
                return diff
            }()

            if changed {
                onCandidateBoxStateChanged(hasBox)
            }

            try? await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
        }
    }

    // MARK: - 窗口检测
    private func hasCandidateWindow() -> Bool {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        for window in windowList {
            guard let layer = window[kCGWindowLayer as String] as? Int,
                  layer >= 0 else { continue }

            guard let ownerName = window[kCGWindowOwnerName as String] as? String else { continue }

            if isInputMethodProcess(ownerName) {
                let windowName = window[kCGWindowName as String] as? String ?? ""
                if isCandidateWindow(windowName) {
                    return true
                }
            }
        }

        return false
    }

    private func isInputMethodProcess(_ name: String) -> Bool {
        let inputMethodKeywords = [
            "Input Method",
            "SCIM",
            "IMK",
            "Sogou",
            "百度",
            "搜狗",
            "Tencent",
            "微信"
        ]

        return inputMethodKeywords.contains { name.contains($0) }
    }

    private func isCandidateWindow(_ name: String) -> Bool {
        if name.isEmpty { return true }

        let candidateKeywords = ["候选", "Candidate", "Input", "Composition"]
        return candidateKeywords.contains { name.contains($0) }
    }
}
