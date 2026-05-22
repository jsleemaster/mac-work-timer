import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let hasSession = model.currentSession != nil

        ZStack {
            Color(red: 0.96, green: 0.965, blue: 0.95)
            .ignoresSafeArea()

            if !hasSession {
                LoginView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                WorkTimerView()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.currentSession)
        .frame(
            minWidth: hasSession ? 420 : 560,
            minHeight: hasSession ? 250 : 520
        )
        .onAppear {
            MainWindowController.shared.resizeForCurrentState()
        }
        .onChange(of: hasSession) { _, _ in
            MainWindowController.shared.resizeForCurrentState()
        }
    }
}

private struct LoginView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("GW 로그인")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("출근 기록이 잡히면 이 화면은 사라지고 타이머만 남습니다.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ProgressView()
                    .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            GWWebLoginView { text in
                model.applyAttendanceText(text)
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            if let message = model.statusMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 20)
            }
        }
    }
}

private struct WorkTimerView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showRemaining = true
    @State private var quote = WorkQuote.random()

    private var timerComponents: TimerComponents {
        TimerComponents(interval: showRemaining ? (model.remaining ?? 0) : (model.elapsed ?? 0))
    }

    private var timerTypography: TimerTypography {
        TimerTypography(remaining: model.remaining ?? 0, isShowingRemaining: showRemaining)
    }

    private var headerTitle: String {
        showRemaining ? "출근" : "출근 후"
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(headerTitle)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.cyan)
                    Text(quote.text)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.black.opacity(0.36))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .help(quote.text)
                    if let session = model.currentSession {
                        Text(DateFormatting.full.string(from: session.workStartAt))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.black.opacity(0.64))
                    }
                }

                Spacer()

                Button {
                    model.refreshAttendance()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.black.opacity(0.62))
                .controlSize(.regular)
                .help("출근 기록 다시 조회")
                .liquidGlassButtonStyle()

                Button {
                    model.logout()
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.black.opacity(0.62))
                .controlSize(.regular)
                .help("로그아웃")
                .liquidGlassButtonStyle()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .liquidGlass(
                in: RoundedRectangle(cornerRadius: 20, style: .continuous),
                tint: nil,
                interactive: true
            )

            FlowingTimerText(components: timerComponents, typography: timerTypography, countsDown: showRemaining)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .liquidGlass(
                    in: RoundedRectangle(cornerRadius: 26, style: .continuous),
                    tint: nil,
                    interactive: true
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.smooth(duration: 0.24)) {
                        showRemaining.toggle()
                        quote = WorkQuote.random(excluding: quote)
                    }
                }
                .help("클릭하면 남은 시간과 흐른 시간을 전환합니다.")

            if let message = model.statusMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                withAnimation(.smooth(duration: 0.35)) {
                    quote = WorkQuote.random(excluding: quote)
                }
            }
        }
    }
}

private struct WorkQuote: Equatable {
    let text: String

    static func random() -> WorkQuote {
        all.randomElement() ?? all[0]
    }

    static func random(excluding current: WorkQuote) -> WorkQuote {
        let candidates = all.filter { $0 != current }
        return candidates.randomElement() ?? random()
    }

    private static let all: [WorkQuote] = [
        WorkQuote(text: "필사즉생 필생즉사 - 이순신"),
        WorkQuote(text: "오늘 할 일을 내일로 미루지 말라 - 벤저민 프랭클린"),
        WorkQuote(text: "천천히 서둘러라 - 아우구스투스"),
        WorkQuote(text: "시작이 반이다 - 속담"),
        WorkQuote(text: "뜻이 있는 곳에 길이 있다 - 속담"),
        WorkQuote(text: "하루라도 책을 읽지 않으면 입안에 가시가 돋는다 - 안중근"),
        WorkQuote(text: "배우고 때때로 익히면 또한 기쁘지 아니한가 - 공자"),
        WorkQuote(text: "행동은 모든 성공의 기초다 - 파블로 피카소")
    ]
}

private struct TimerComponents: Equatable {
    let hours: Int
    let minutes: Int
    let seconds: Int

    init(interval: TimeInterval) {
        let totalSeconds = max(0, Int(interval.rounded()))
        self.hours = totalSeconds / 3600
        self.minutes = (totalSeconds % 3600) / 60
        self.seconds = totalSeconds % 60
    }

    var hourText: String {
        String(format: "%02d", hours)
    }

    var minuteText: String {
        String(format: "%02d", minutes)
    }

    var secondText: String {
        String(format: "%02d", seconds)
    }
}

private struct TimerTypography: Equatable {
    let numberSize: CGFloat
    let colonSize: CGFloat
    let unitWidth: CGFloat
    let height: CGFloat

    init(remaining: TimeInterval, isShowingRemaining: Bool) {
        guard isShowingRemaining else {
            self.init(numberSize: 54, colonSize: 48, unitWidth: 74, height: 86)
            return
        }

        switch remaining {
        case ..<TimeInterval(5 * 60):
            self.init(numberSize: 70, colonSize: 62, unitWidth: 90, height: 92)
        case ..<TimeInterval(30 * 60):
            self.init(numberSize: 64, colonSize: 56, unitWidth: 84, height: 90)
        case ..<TimeInterval(60 * 60):
            self.init(numberSize: 58, colonSize: 52, unitWidth: 78, height: 88)
        default:
            self.init(numberSize: 54, colonSize: 48, unitWidth: 74, height: 86)
        }
    }

    private init(numberSize: CGFloat, colonSize: CGFloat, unitWidth: CGFloat, height: CGFloat) {
        self.numberSize = numberSize
        self.colonSize = colonSize
        self.unitWidth = unitWidth
        self.height = height
    }
}

private struct FlowingTimerText: View {
    let components: TimerComponents
    let typography: TimerTypography
    let countsDown: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            FlowingTimeUnit(value: components.hourText, typography: typography, countsDown: countsDown)
            TimerColon(typography: typography)
            FlowingTimeUnit(value: components.minuteText, typography: typography, countsDown: countsDown)
            TimerColon(typography: typography)
            FlowingTimeUnit(value: components.secondText, typography: typography, countsDown: countsDown)
        }
        .frame(height: typography.height)
        .animation(.smooth(duration: 0.24), value: typography)
    }
}

private struct FlowingTimeUnit: View {
    let value: String
    let typography: TimerTypography
    let countsDown: Bool

    var body: some View {
        unitText
            .foregroundStyle(Color(red: 0.08, green: 0.12, blue: 0.13))
        .frame(width: typography.unitWidth, height: typography.height)
        .clipped()
        .contentTransition(.numericText(countsDown: countsDown))
        .animation(.smooth(duration: 0.28), value: value)
        .animation(.smooth(duration: 0.24), value: typography)
    }

    private var unitText: some View {
        Text(value)
            .font(.system(size: typography.numberSize, weight: .bold, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.72)
            .lineLimit(1)
    }
}

private struct TimerColon: View {
    let typography: TimerTypography

    var body: some View {
        Text(":")
            .font(.system(size: typography.colonSize, weight: .bold, design: .rounded))
            .foregroundStyle(Color(red: 0.08, green: 0.12, blue: 0.13).opacity(0.76))
            .frame(width: 16)
            .animation(.smooth(duration: 0.24), value: typography)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Toggle("로그인 시 자동 실행", isOn: Binding(
            get: { model.launchAtLogin },
            set: { model.setLaunchAtLogin($0) }
        ))
        .padding(22)
        .frame(width: 320)
    }
}

#if DEBUG
private struct TimerAnimationReferencePreview: View {
    @State private var stepIndex = 0

    private let steps: [TimeInterval] = [
        TimeInterval(2 * 60 * 60 + 40 * 60 + 9),
        TimeInterval(59 * 60 + 59),
        TimeInterval(29 * 60 + 59),
        TimeInterval(4 * 60 + 59),
        TimeInterval(29)
    ]

    private var remaining: TimeInterval {
        steps[stepIndex]
    }

    private var typography: TimerTypography {
        TimerTypography(remaining: remaining, isShowingRemaining: true)
    }

    var body: some View {
        VStack(spacing: 16) {
            FlowingTimerText(
                components: TimerComponents(interval: remaining),
                typography: typography,
                countsDown: true
            )
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .liquidGlass(
                in: RoundedRectangle(cornerRadius: 26, style: .continuous),
                tint: nil,
                interactive: true
            )

            HStack(spacing: 8) {
                ForEach(steps.indices, id: \.self) { index in
                    Circle()
                        .fill(index == stepIndex ? Color.cyan : Color.black.opacity(0.12))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .padding(18)
        .frame(width: 430, height: 190)
        .background(Color(red: 0.96, green: 0.965, blue: 0.95))
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.4))
                withAnimation(.smooth(duration: 0.32)) {
                    stepIndex = (stepIndex + 1) % steps.count
                }
            }
        }
    }
}

private struct TimerAnimationReferencePreview_Previews: PreviewProvider {
    static var previews: some View {
        TimerAnimationReferencePreview()
            .previewDisplayName("Timer Motion Reference")
    }
}
#endif
