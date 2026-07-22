import Foundation
import MacWorkTimerCore
import UserNotifications

@MainActor
final class NotificationService {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func scheduleCompletionNotification(for session: WorkSession, targetAt: Date, from now: Date) async {
        let interval = targetAt.timeIntervalSince(now)
        guard interval > 1 else {
            return
        }

        let content = completionContent()
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationID(for: session),
            content: content,
            trigger: trigger
        )

        center.removePendingNotificationRequests(withIdentifiers: [notificationID(for: session)])
        try? await center.add(request)
    }

    func deliverCompletionNotification(for session: WorkSession, targetAt: Date) async {
        let request = UNNotificationRequest(
            identifier: notificationID(for: session),
            content: completionContent(),
            trigger: nil
        )

        center.removePendingNotificationRequests(withIdentifiers: [notificationID(for: session)])
        try? await center.add(request)
    }

    private func completionContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "퇴근 알림"
        content.body = "오늘 쓸 수 있는 시간까지 채웠어요. GW 또는 세콤 상태를 확인해 주세요."
        content.sound = .default
        return content
    }

    private func notificationID(for session: WorkSession) -> String {
        "mac-work-timer-\(session.workDate)"
    }
}
