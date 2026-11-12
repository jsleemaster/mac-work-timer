import MacWorkTimerCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let hasSession = model.currentSession != nil
        let needsWeeklyLoginRecovery = model.needsWeeklyLoginRecovery
        let showsLogin = !hasSession || needsWeeklyLoginRecovery

        ZStack {
            Color(red: 0.96, green: 0.965, blue: 0.95)
            .ignoresSafeArea()

            if showsLogin {
                LoginView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                Color.clear
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.currentSession)
        .frame(
            minWidth: MainWindowMetrics.contentSize(hasSession: hasSession, showsLogin: showsLogin).width,
            minHeight: MainWindowMetrics.contentSize(hasSession: hasSession, showsLogin: showsLogin).height
        )
        .onAppear {
            updateMainWindowVisibility(
                hasSession: hasSession,
                needsWeeklyLoginRecovery: needsWeeklyLoginRecovery
            )
        }
        .onChange(of: showsLogin) { _, _ in
            updateMainWindowVisibility(
                hasSession: hasSession,
                needsWeeklyLoginRecovery: needsWeeklyLoginRecovery
            )
        }
    }

    private func updateMainWindowVisibility(hasSession: Bool, needsWeeklyLoginRecovery: Bool) {
        if MainWindowPresentationPolicy.shouldHideMainWindow(
            hasSession: hasSession,
            needsWeeklyLoginRecovery: needsWeeklyLoginRecovery
        ) {
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
                    Text(model.needsWeeklyLoginRecovery
                        ? "이번 주 근태를 불러오면 이 창은 닫히고 펫에 바로 표시됩니다."
                        : "출근 기록이 잡히면 이 창은 닫히고 펫만 남습니다.")
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

            if !model.missingCheckOuts.isEmpty {
                MissingCheckOutSection()
                    .padding(.horizontal, 20)
            }

            GWWebLoginView(
                onAuthenticatedSession: {
                    model.authenticatedWebSessionDidBecomeAvailable()
                },
                onAttendanceText: { text in
                    model.applyAttendanceText(text)
                }
            )
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
        VStack(alignment: .leading, spacing: 18) {
            Toggle("로그인 시 자동 실행", isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            ))

            Divider()

            HolidaySettingsSection()

            if !model.manualCheckOuts.isEmpty {
                Divider()

                ManualCheckOutSettingsSection()
            }
        }
        .padding(22)
        .frame(width: 380)
    }
}

private struct HolidaySettingsSection: View {
    @EnvironmentObject private var model: AppModel
    @State private var draftDate = Date()
    @State private var draftTitle = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("휴일")
                .font(.system(size: 13, weight: .semibold))
            Text("등록한 날은 주말처럼 취급됩니다. 주간 40시간 목표에서 빠지고, 그날 근무한 시간은 여유가 아닌 초과근무로 집계됩니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("지난 날짜도 등록할 수 있습니다. 이번 주 안의 날짜라면 주간 집계가 바로 다시 계산됩니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                DatePicker("", selection: $draftDate, displayedComponents: .date)
                    .labelsHidden()
                TextField(HolidayEntry.defaultTitle, text: $draftTitle)
                    .textFieldStyle(.roundedBorder)
                Button("추가") {
                    model.setHoliday(true, for: model.workDateText(for: draftDate), title: draftTitle)
                    draftTitle = ""
                }
            }

            if model.holidays.isEmpty {
                Text("등록된 휴일이 없습니다. GW 근태표의 공휴일은 자동으로 반영됩니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(model.holidays, id: \.workDate) { holiday in
                        HStack {
                            Text(holiday.workDate)
                                .font(.system(size: 12, design: .monospaced))
                            Text(holiday.title)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                model.setHoliday(false, for: holiday.workDate)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("휴일 지정 해제")
                        }
                        .padding(.vertical, 4)
                        Divider()
                    }
                }
                .frame(maxHeight: 160)
            }
        }
    }
}

/// Lets the user type in a check-out GW never recorded, so a forgotten tag-out stops the
/// weekly summary from staying incomplete (and this window from staying open) all week.
private struct MissingCheckOutSection: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("퇴근 기록이 없는 날")
                .font(.system(size: 13, weight: .semibold))
            Text("GW 에 출근만 찍힌 날이 있어 주간 집계를 끝낼 수 없습니다. 퇴근 시각을 직접 넣으면 바로 다시 계산되고, 나중에 GW 에 퇴근 기록이 생기면 그 값이 우선합니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(model.missingCheckOuts, id: \.workDate) { record in
                MissingCheckOutRow(record: record)
            }
        }
        .padding(12)
        .background(.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct MissingCheckOutRow: View {
    @EnvironmentObject private var model: AppModel
    let record: WeeklyAttendanceRecord
    @State private var draftTime: Date

    init(record: WeeklyAttendanceRecord) {
        self.record = record
        // Start from a full day after check-in (8h + lunch), the most likely tag-out.
        let suggested = (record.checkInAt ?? Date()).addingTimeInterval(9 * 60 * 60)
        _draftTime = State(initialValue: suggested)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(record.workDate)
                .font(.system(size: 12, design: .monospaced))
            if let checkInAt = record.checkInAt {
                Text("출근 \(DateFormatting.time.string(from: checkInAt))")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("퇴근")
                .font(.system(size: 12))
            DatePicker("", selection: $draftTime, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .environment(\.timeZone, TimeZone(identifier: "Asia/Seoul")!)
            Button("입력") {
                model.setManualCheckOut(draftTime, for: record)
            }
        }
    }
}

private struct ManualCheckOutSettingsSection: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("직접 입력한 퇴근")
                .font(.system(size: 13, weight: .semibold))
            Text("GW 에 퇴근 기록이 없어 직접 넣은 값입니다. 지우면 다시 입력할 수 있습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(model.manualCheckOuts, id: \.workDate) { entry in
                HStack {
                    Text(entry.workDate)
                        .font(.system(size: 12, design: .monospaced))
                    Text("퇴근 \(DateFormatting.time.string(from: entry.checkOutAt))")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        model.clearManualCheckOut(for: entry.workDate)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("직접 입력한 퇴근 삭제")
                }
            }
        }
    }
}
