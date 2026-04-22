import SwiftUI

/// 浮动指示器 — macOS 原生材质风格
///
/// 磨砂玻璃背景自动适配亮/暗模式，纯系统语义色，接近单色系。
struct ProgressRingIndicator: View {
    let appState: AppState
    let onTap: () -> Void
    let onDoubleTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private let diameter: CGFloat = 38
    private let ringWidth: CGFloat = 1.8
    private let arcColor = Color.primary.opacity(0.35)

    var body: some View {
        ZStack {
            dial
            trackRing
            progressArc
            glyph
        }
        .frame(width: 46, height: 46)
        .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        .onAppear { startPulseIfNeeded() }
        .onChange(of: appState.currentInputState) { _, _ in startPulseIfNeeded() }
        .onChange(of: appState.countdownSeconds) { old, new in
            if (old > 5) != (new > 5) { startPulseIfNeeded() }
        }
        .highPriorityGesture(TapGesture(count: 2).onEnded { onDoubleTap() })
        .onTapGesture { onTap() }
    }

    // MARK: - 表盘（磨砂玻璃材质）

    private var dial: some View {
        Circle()
            .fill(.regularMaterial)
            .frame(width: diameter, height: diameter)
    }

    // MARK: - 环轨

    private var trackRing: some View {
        Circle()
            .stroke(Color.primary.opacity(0.08), lineWidth: ringWidth)
            .frame(width: diameter - 4, height: diameter - 4)
    }

    // MARK: - 进度弧（仅倒计时中显示）

    @ViewBuilder
    private var progressArc: some View {
        if showArc {
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    arcColor,
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .frame(width: diameter - 4, height: diameter - 4)
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)
                .opacity(pulse ? 0.55 : 1.0)
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
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .tracking(0.5)
            .foregroundStyle(glyphColor)
            .contentTransition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: stateText)
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

    private var glyphColor: Color {
        switch appState.currentInputState {
        case .english:
            return .secondary
        case .chineseIdle, .chineseTyping, .chineseCountdown:
            return .primary
        }
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
