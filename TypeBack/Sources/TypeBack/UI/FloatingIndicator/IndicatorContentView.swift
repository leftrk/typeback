import SwiftUI

/// 浮动指示器 — 白底黑字 / 黑底白字，带外发光光晕和状态切换水波动画
struct ProgressRingIndicator: View {
    let appState: AppState
    var containerSize: CGFloat = 84

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    @State private var ripples: [Ripple] = []

    private let diameter: CGFloat = 40
    private let ringWidth: CGFloat = 1.6

    private var isChinese: Bool { appState.currentInputState != .english }

    var body: some View {
        ZStack {
            ripplesLayer
            glowLayer
            dial
            progressArc
            glyph
        }
        .frame(width: containerSize, height: containerSize)
        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 2)
        .animation(.easeInOut(duration: 0.3), value: isChinese)
        .onAppear { startPulseIfNeeded() }
        .onChange(of: appState.currentInputState) { oldValue, newValue in
            startPulseIfNeeded()
            triggerRippleIfStateFlipped(from: oldValue, to: newValue)
        }
        .onChange(of: appState.countdownSeconds) { old, new in
            if (old > 5) != (new > 5) { startPulseIfNeeded() }
        }
        .contentShape(Circle())
        .onTapGesture {
            handleTap()
        }
    }

    // MARK: - 配色

    /// 光晕用冷白光，不随状态变色
    private var accentColor: Color {
        Color(red: 0.92, green: 0.96, blue: 1.00)
    }

    /// 水波颜色：EN 白色，CN 黑色
    private var rippleColor: Color {
        isChinese ? Color.black : Color.white
    }

    // MARK: - 外发光光晕

    private var glowLayer: some View {
        Circle()
            .fill(accentColor)
            .frame(width: diameter, height: diameter)
            .blur(radius: 10)
            .opacity(0.55)
    }

    // MARK: - 水波动画

    private var ripplesLayer: some View {
        ZStack {
            ForEach(ripples) { ripple in
                RippleView(
                    startDiameter: diameter,
                    endDiameter: containerSize,
                    color: ripple.color,
                    duration: 1.2,
                    onComplete: { removeRipple(id: ripple.id) }
                )
            }
        }
    }

    private func triggerRippleIfStateFlipped(from old: InputState, to new: InputState) {
        let oldIsChinese = old != .english
        let newIsChinese = new != .english
        guard oldIsChinese != newIsChinese else { return }
        guard !reduceMotion else { return }
        spawnRipple()
    }

    private func spawnRipple() {
        guard !reduceMotion else { return }
        let color = rippleColor
        ripples.append(Ripple(color: color))
        // 间隔 130ms 再发一层，形成涟漪叠浪
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            self.ripples.append(Ripple(color: color))
        }
    }

    private func handleTap() {
        spawnRipple()
    }

    private func removeRipple(id: UUID) {
        ripples.removeAll { $0.id == id }
    }

    // MARK: - 表盘

    /// EN/CN 都用纯毛玻璃
    private var dialMaterial: AnyShapeStyle {
        AnyShapeStyle(.ultraThinMaterial)
    }

    private var dial: some View {
        Circle()
            .fill(isChinese
                ? AnyShapeStyle(Color.black.opacity(0.5))
                : AnyShapeStyle(.ultraThinMaterial)
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
            .font(.system(size: 12, weight: .medium, design: .rounded))
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

// MARK: - 水波模型与视图

private struct Ripple: Identifiable {
    let id = UUID()
    let color: Color
}

private struct RippleView: View {
    let startDiameter: CGFloat
    let endDiameter: CGFloat
    let color: Color
    let duration: Double
    let onComplete: () -> Void

    @State private var animated = false

    var body: some View {
        Circle()
            .stroke(color, lineWidth: animated ? 0 : 3)
            .frame(
                width: animated ? endDiameter : startDiameter,
                height: animated ? endDiameter : startDiameter
            )
            .opacity(animated ? 0 : 0.95)
            .onAppear {
                withAnimation(.easeOut(duration: duration)) {
                    animated = true
                }
                Task {
                    try? await Task.sleep(
                        nanoseconds: UInt64(duration * 1_000_000_000) + 100_000_000
                    )
                    await MainActor.run { onComplete() }
                }
            }
    }
}

struct IndicatorView: View {
    let appState: AppState

    var body: some View {
        ProgressRingIndicator(appState: appState)
    }
}
