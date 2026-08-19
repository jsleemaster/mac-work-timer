import AppKit
import MacWorkTimerCore

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    static let shared = StatusBarController(model: .shared)

    private let model: AppModel
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let loginItem = NSMenuItem(title: "GW 로그인 열기", action: #selector(openWindow), keyEquivalent: "o")
    private let workdayModeParentItem = NSMenuItem(title: "근무 형태", action: nil, keyEquivalent: "")
    private let workdayModeMenu = NSMenu()
    private let checkInItem = NSMenuItem()
    private let targetItem = NSMenuItem()
    private let weeklyBalanceItem = NSMenuItem()
    private let weeklyOvertimeItem = NSMenuItem()
    private let weeklyHolidayItem = NSMenuItem()
    private let holidayParentItem = NSMenuItem(title: "휴일로 표시", action: nil, keyEquivalent: "")
    private let holidayMenu = NSMenu()
    private let allFlexUsedTargetItem = NSMenuItem()
    private let weeklyFetchedAtItem = NSMenuItem()
    private let remainingItem = NSMenuItem()
    private let progressItem = NSMenuItem()
    private let agentUsageItem = NSMenuItem()
    private let petItem = NSMenuItem()
    private let revealPetItem = NSMenuItem()
    private var workdayModeItems: [WorkdayMode: NSMenuItem] = [:]
    private var timer: Timer?

    init(model: AppModel) {
        self.model = model
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureMenu()
        update()
    }

    func start() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.update()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        update()
    }

    private func configureMenu() {
        menu.delegate = self
        checkInItem.isEnabled = false
        targetItem.isEnabled = false
        weeklyBalanceItem.isEnabled = false
        allFlexUsedTargetItem.isEnabled = false
        weeklyFetchedAtItem.isEnabled = false
        remainingItem.isEnabled = false
        progressItem.isEnabled = false
        agentUsageItem.isEnabled = false
        configureWorkdayModeMenu()

        menu.addItem(remainingItem)
        menu.addItem(checkInItem)
        menu.addItem(targetItem)
        menu.addItem(weeklyBalanceItem)
        menu.addItem(weeklyOvertimeItem)
        menu.addItem(weeklyHolidayItem)
        menu.addItem(allFlexUsedTargetItem)
        menu.addItem(weeklyFetchedAtItem)
        menu.addItem(progressItem)
        menu.addItem(agentUsageItem)
        menu.addItem(.separator())
        menu.addItem(loginItem)
        menu.addItem(workdayModeParentItem)
        holidayMenu.delegate = self
        // Locked GW holidays keep an action so the checkmark reads as a real state, so the
        // enabled flag has to be honored literally rather than inferred from the action.
        holidayMenu.autoenablesItems = false
        holidayParentItem.submenu = holidayMenu
        menu.addItem(holidayParentItem)
        rebuildHolidayMenu()
        menu.addItem(NSMenuItem(title: "출근 기록 다시 조회", action: #selector(refreshAttendance), keyEquivalent: "r"))
        petItem.action = #selector(togglePet)
        menu.addItem(petItem)
        revealPetItem.title = "펫 찾기"
        revealPetItem.action = #selector(revealPet)
        menu.addItem(revealPetItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "설정…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "종료", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        statusItem.menu = menu
    }

    private func configureWorkdayModeMenu() {
        workdayModeParentItem.submenu = workdayModeMenu
        workdayModeMenu.removeAllItems()
        workdayModeItems.removeAll()

        for mode in WorkdayMode.allCases {
            let item = NSMenuItem(title: mode.title, action: #selector(selectWorkdayMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            workdayModeMenu.addItem(item)
            workdayModeItems[mode] = item
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard menu !== holidayMenu else {
            return
        }
        update()
    }

    /// The holiday submenu is rebuilt only when it is about to be shown. `update()` runs every
    /// second from the timer, and swapping items out from under an open submenu would fight the
    /// user's pointer.
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu !== holidayMenu else {
            rebuildHolidayMenu()
            return
        }
        update()
    }

    private func update() {
        let remaining = model.remaining ?? 0
        let title = model.currentSession == nil ? "로그인" : MenuBarStatusFormatter.title(remaining: remaining)
        let urgency = MenuBarStatusFormatter.urgency(progress: model.progress)

        if let button = statusItem.button {
            button.attributedTitle = NSAttributedString(
                string: " \(title) ",
                attributes: [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold),
                    .foregroundColor: titleColor(urgency: urgency, hasSession: model.currentSession != nil)
                ]
            )
            button.toolTip = tooltip()
        }

        let hasSession = model.currentSession != nil
        loginItem.isHidden = hasSession && !model.needsWeeklyLoginRecovery

        if let session = model.currentSession {
            checkInItem.title = "출근 \(DateFormatting.time.string(from: session.workStartAt))"
            targetItem.title = "오늘 퇴근 \(DateFormatting.time.string(from: session.targetAt))"
            remainingItem.title = "남은 시간 \(DateFormatting.digital(remaining))"
            progressItem.title = "진행률 \(Int((model.progress * 100).rounded()))%"
        } else if model.isTodayHoliday {
            checkInItem.title = "오늘은 \(model.holidayCalendar.title(for: model.todayWorkDate) ?? HolidayEntry.defaultTitle)입니다"
            targetItem.title = "휴일에는 타이머가 쉽니다"
            remainingItem.title = "남은 시간 --"
            progressItem.title = "진행률 --"
        } else {
            checkInItem.title = "GW 로그인이 필요합니다"
            targetItem.title = "출근 기록 없음"
            remainingItem.title = "남은 시간 --"
            progressItem.title = "진행률 --"
        }
        if let summary = model.weeklySummary, summary.isComplete {
            weeklyBalanceItem.isHidden = false
            allFlexUsedTargetItem.isHidden = false
            weeklyFetchedAtItem.isHidden = false
            weeklyBalanceItem.title = WeeklyWorkCopyFormatter.balanceLine(summary.balance)
            allFlexUsedTargetItem.title = "오늘 다 쓰면 \(DateFormatting.time.string(from: summary.allFlexUsedTargetAt))"
            weeklyFetchedAtItem.title = "마지막 확인 \(DateFormatting.time.string(from: summary.fetchedAt))"

            if let overtime = WeeklyWorkCopyFormatter.overtimeLine(summary.overtimeDuration) {
                weeklyOvertimeItem.isHidden = false
                weeklyOvertimeItem.title = overtime
            } else {
                weeklyOvertimeItem.isHidden = true
            }
            if let holidayLine = WeeklyWorkCopyFormatter.holidayLine(summary.holidayWorkDates) {
                weeklyHolidayItem.isHidden = false
                weeklyHolidayItem.title = holidayLine
            } else {
                weeklyHolidayItem.isHidden = true
            }
        } else {
            weeklyBalanceItem.isHidden = true
            weeklyOvertimeItem.isHidden = true
            weeklyHolidayItem.isHidden = true
            allFlexUsedTargetItem.isHidden = true
            weeklyFetchedAtItem.isHidden = true
        }
        if let agentUsageLine = model.agentUsageLine {
            agentUsageItem.isHidden = false
            agentUsageItem.title = "AI 제한 \(agentUsageLine)"
        } else {
            agentUsageItem.isHidden = true
            agentUsageItem.title = ""
        }

        for (mode, item) in workdayModeItems {
            item.state = mode == model.workdayMode ? .on : .off
        }

        petItem.title = PetWindowController.shared.isVisible ? "펫 숨기기" : "펫 보이기"
    }

    /// Lists this week's weekdays so a day that has already passed can be marked a holiday too,
    /// and not just today. GW-derived holidays are shown checked but locked, because unchecking
    /// them here would only be overwritten by the next weekly refresh.
    private func rebuildHolidayMenu() {
        holidayMenu.removeAllItems()

        for option in model.holidayMenuOptions {
            let item = NSMenuItem(title: option.label, action: #selector(toggleHoliday(_:)), keyEquivalent: "")
            item.state = option.isHoliday ? .on : .off
            item.representedObject = option.workDate
            item.isEnabled = !option.isLocked
            item.target = self
            holidayMenu.addItem(item)
        }

        holidayMenu.addItem(.separator())
        let otherDatesItem = NSMenuItem(title: "다른 날짜…", action: #selector(openSettings), keyEquivalent: "")
        otherDatesItem.isEnabled = true
        otherDatesItem.target = self
        holidayMenu.addItem(otherDatesItem)
    }

    private func tooltip() -> String {
        guard let session = model.currentSession else {
            if model.isTodayHoliday {
                return "오늘은 \(model.holidayCalendar.title(for: model.todayWorkDate) ?? HolidayEntry.defaultTitle)입니다."
            }
            return "GW 로그인 후 출근 기록을 읽습니다."
        }
        var parts = [
            "출근 \(DateFormatting.time.string(from: session.workStartAt))",
            "오늘 퇴근 \(DateFormatting.time.string(from: session.targetAt))"
        ]
        if let summary = model.weeklySummary, summary.isComplete {
            parts.append(WeeklyWorkCopyFormatter.balanceLine(summary.balance))
            if let overtime = WeeklyWorkCopyFormatter.overtimeLine(summary.overtimeDuration) {
                parts.append(overtime)
            }
            parts.append("오늘 다 쓰면 \(DateFormatting.time.string(from: summary.allFlexUsedTargetAt))")
        }
        if let usage = model.agentUsageLine {
            parts.append(usage)
        }
        return parts.joined(separator: " · ")
    }

    private func titleColor(urgency: Double, hasSession: Bool) -> NSColor {
        guard hasSession else {
            return .white
        }

        let greenBlue = CGFloat(1 - urgency)
        return NSColor(calibratedRed: 1, green: greenBlue, blue: greenBlue, alpha: 1)
    }

    @objc private func openWindow() {
        MainWindowController.shared.showLogin()
    }

    @objc private func refreshAttendance() {
        model.refreshAttendance(force: true, allowWebSessionProbe: true)
    }

    @objc private func selectWorkdayMode(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = WorkdayMode(rawValue: rawValue) else {
            return
        }

        model.setWorkdayMode(mode)
        update()
    }

    @objc private func toggleHoliday(_ sender: NSMenuItem) {
        guard let workDate = sender.representedObject as? String else {
            return
        }

        model.toggleHoliday(for: workDate)
        update()
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func togglePet() {
        PetWindowController.shared.toggleVisibility()
        update()
    }

    @objc private func revealPet() {
        PetWindowController.shared.revealNearMouse()
        update()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
