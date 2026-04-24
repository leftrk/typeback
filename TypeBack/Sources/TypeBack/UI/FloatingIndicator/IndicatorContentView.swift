import SwiftUI

/// 浮动指示器 — 白底黑字 / 黑底白字
struct ProgressRingIndicator: View {
    let appState: AppState
    let onTap: () -> Void
    let onDoubleTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private let diameter: CGFloat = 36
    private let ringWidth: CGFloat = 1.6

    private var isChinese: Bool { appState.currentInputState != .english }

    var body: some View {
        ZStack {
            dial
            progressArc
            glyph
        }
        .frame(width: 52, height: 52)
        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 2)
        .animation(.easeInOut(duration: 0.3), value: isChinese)
        .onAppear { startPulseIfNeeded() }
        .onChange(of: appState.currentInputState) { _, _ in startPulseIfNeeded() }
        .onChange(of: appState.countdownSeconds) { old, new in
            if (old > 5) != (new > 5) { startPulseIfNeeded() }
        }
        .highPriorityGesture(TapGesture(count: 2).onEnded { onDoubleTap() })
        .onTapGesture { onTap() }
    }

    // MARK: - 表盘

    private var dial: some View {
        Circle()
            .fill(isChinese
                ? Color(white: 0.12).opacity(0.9)
                : Color(white: 0.97).opacity(0.9)
            )
            .frame(width: diameter, height: diameter)
            .animation(.easeInOut(duration: 0.3), value: isChinese)
    }

    // MARK: - 进度弧

    @ViewBuilder
    private var progressArc: some View {
        if showArc {
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.white.opacity(0.75),
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .frame(width: diameter - 3, height: diameter - 3)
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)
                .opacity(pulse ? 0.5 : 1.0)
                .animation(.easeInOut(duration: 0.9), value: pulse)
        }
    }

    private var showArc: Bool {
        if case .chineseCountdown = appState.currentInputState { return true }
        return false
    }

    // MARK: - 中心字形

    private var glyph: some View {
        Text(stateText)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .tracking(0.3)
            .foregroundStyle(isChinese
                ? Color.white.opacity(0.8)
                : Color.black.opacity(0.45)
            )
            .contentTransition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: stateText)
            .animation(.easeInOut(duration: 0.3), value: isChinese)
    }

    // MARK: - 计算

    private var stateText: String {
        switch appState.currentInputState {
        case .english: return "EN"
        case .chineseIdle, .chineseTyping, .chineseCountdown: return "CN"
        }
    }

    private var progress: Double {
        guard case .chineseCountdown = appState.currentInputState else { return 1.0 }
        let total = max(1, appState.timeoutSeconds)
        return max(0, min(1, Double(appState.countdownSeconds) / Double(total)))
    }

    // MARK: - 末段脉冲

    private func startPulseIfNeeded() {
        guard !reduceMotion else { pulse = false; return }
        let inCritical: Bool = {
            if case .chineseCountdown = appState.currentInputState {
                return appState.countdownSeconds <= 5
            }
            return false
        }()
        if inCritical {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        } else {
            withAnimation(.easeInOut(duration: 0.3)) { pulse = false }
        }
    }
}

struct IndicatorView: View {
    let appState: AppState
    let onTap: () -> Void
    let onDoubleTap: () -> Void

    var body: some View {
        ProgressRingIndicator(
            appState: appState,
            onTap: onTap,
            onDoubleTap: onDoubleTap
        )
    }
}
