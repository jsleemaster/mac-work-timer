import AppKit
import MacWorkTimerCore

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    static let shared = StatusBarController(model: .shared)

    private let model: AppModel
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let checkInItem = NSMenuItem()
    private let targetItem = NSMenuItem()
    private let remainingItem = NSMenuItem()
    private let progressItem = NSMenuItem()
    private let petItem = NSMenuItem()
    private let revealPetItem = NSMenuItem()
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
        remainingItem.isEnabled = false
        progressItem.isEnabled = false

        menu.addItem(checkInItem)
        menu.addItem(targetItem)
        menu.addItem(remainingItem)
        menu.addItem(progressItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "창 열기", action: #selector(openWindow), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "출근 기록 다시 조회", action: #selector(refreshAttendance), keyEquivalent: "r"))
        petItem.action = #selector(togglePet)
        menu.addItem(petItem)
        revealPetItem.title = "펫 찾기"
        revealPetItem.action = #selector(revealPet)
        menu.addItem(revealPetItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "종료", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        update()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
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

        if let session = model.currentSession {
            checkInItem.title = "출근 \(DateFormatting.time.string(from: session.workStartAt))"
            targetItem.title = "퇴근 목표 \(DateFormatting.time.string(from: session.targetAt))"
            remainingItem.title = "남은 시간 \(DateFormatting.digital(remaining))"
            progressItem.title = "진행률 \(Int((model.progress * 100).rounded()))%"
        } else {
            checkInItem.title = "GW 로그인이 필요합니다"
            targetItem.title = "출근 기록 없음"
            remainingItem.title = "남은 시간 --"
            progressItem.title = "진행률 --"
        }

        petItem.title = PetWindowController.shared.isVisible ? "펫 숨기기" : "펫 보이기"
    }

    private func tooltip() -> String {
        guard let session = model.currentSession else {
            return "GW 로그인 후 출근 기록을 읽습니다."
        }
        return "출근 \(DateFormatting.time.string(from: session.workStartAt)) · 목표 \(DateFormatting.time.string(from: session.targetAt))"
    }

    private func titleColor(urgency: Double, hasSession: Bool) -> NSColor {
        guard hasSession else {
            return .white
        }

        let greenBlue = CGFloat(1 - urgency)
        return NSColor(calibratedRed: 1, green: greenBlue, blue: greenBlue, alpha: 1)
    }

    @objc private func openWindow() {
        MainWindowController.shared.show()
    }

    @objc private func refreshAttendance() {
        model.refreshAttendance()
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
