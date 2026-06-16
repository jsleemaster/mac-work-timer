import MacWorkTimerCore
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
                Color.clear
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.currentSession)
        .frame(
            minWidth: MainWindowMetrics.contentSize(hasSession: hasSession).width,
            minHeight: MainWindowMetrics.contentSize(hasSession: hasSession).height
        )
        .onAppear {
            updateMainWindowVisibility(hasSession: hasSession)
        }
        .onChange(of: hasSession) { _, _ in
            updateMainWindowVisibility(hasSession: hasSession)
        }
    }

    private func updateMainWindowVisibility(hasSession: Bool) {
        if MainWindowPresentationPolicy.shouldHideMainWindow(hasSession: hasSession) {
            MainWindowController.shared.hide()
        } else {
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
                    Text("출근 기록이 잡히면 이 창은 닫히고 펫만 남습니다.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if model.isLoggingIn {
                    ProgressView()
                        .controlSize(.small)
                }
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
