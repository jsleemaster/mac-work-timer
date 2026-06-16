import XCTest
@testable import MacWorkTimerCore

final class SystemActivityLogParserTests: XCTestCase {
    func testFindsFirstUserActivityForWorkDate() throws {
        let log = """
        2026-05-29 08:42:33 +0900 Assertions           PID 53798(Amphetamine) Summary PreventUserIdleDisplaySleep "Amphetamine"
        2026-05-29 08:55:00 +0900 Assertions           PID 421(WindowServer) Created UserIsActive "com.apple.iohideventsystem.queue.tickle serviceID:1001756c0 service:AppleMultitouchDevice product:Magic Trackpad eventType:11"
        2026-05-29 08:55:04 +0900 Assertions           PID 424(loginwindow) Created UserIsActive "Loginwindow User Activity"
        2026-05-29 10:27:33 +0900 Assertions           PID 421(WindowServer) Summary UserIsActive "later"
        """

        let start = SystemActivityLogParser.firstUserActivity(in: log, workDate: "2026-05-29")

        let expected = try XCTUnwrap(DateComponents(
            calendar: Calendar.gregorianSeoul,
            timeZone: TimeZone(identifier: "Asia/Seoul"),
            year: 2026,
            month: 5,
            day: 29,
            hour: 8,
            minute: 55,
            second: 0
        ).date)
        XCTAssertEqual(start, expected)
    }

    func testIgnoresNonUserActivityAssertions() {
        let log = """
        2026-05-29 08:42:33 +0900 Assertions           PID 53798(Amphetamine) Summary PreventUserIdleDisplaySleep "Amphetamine"
        2026-05-29 09:09:25 +0900 Assertions           PID 73958(PowerUIAgent) Created MaintenanceWake "com.apple.obc"
        """

        XCTAssertNil(SystemActivityLogParser.firstUserActivity(in: log, workDate: "2026-05-29"))
    }

    func testIgnoresSleepWakeActivityAndUsesFirstFreshInput() throws {
        let log = """
        2026-06-15 06:12:13 +0900 Assertions           PID 599(powerd) Created UserIsActive "com.apple.powermanagement.kernel.useractive AppleUserHIDEventDriver:sleepDisplayTickle kIOMessageSystemWillS" 00:00:00  id:0x0x90000a599 [System: PrevIdle DeclUser PushSrvc BGTask SRPrevSleep kCPU kDisp]
        2026-06-15 06:12:13 +0900 Assertions           PID 659(WindowServer) Created UserIsActive "com.apple.iohideventsystem.queue.tickle serviceID:100001362 service:AppleUserHIDEventService product:QK ALICE eventType:3" 00:00:00  id:0x0x90000a59a [System: PrevIdle DeclUser PushSrvc BGTask SRPrevSleep kCPU kDisp]
        2026-06-15 06:27:45 +0900 Assertions           PID 659(WindowServer) Summary UserIsActive "com.apple.iohideventsystem.queue.tickle serviceID:100001362 service:AppleUserHIDEventService product:QK ALICE eventType:3" 00:15:31  id:0x0x90000a59a [System: PrevIdle DeclUser kDisp]
        2026-06-15 09:19:10 +0900 Assertions           PID 659(WindowServer) Created UserIsActive "com.apple.iohideventsystem.queue.tickle serviceID:100041d5b service:AppleMultitouchDevice product:Magic Trackpad eventType:17" 00:00:00  id:0x0x90000838b [System: PrevIdle DeclUser kDisp]
        2026-06-15 09:19:31 +0900 Assertions           PID 662(loginwindow) Created UserIsActive "Loginwindow User Activity" 00:00:00  id:0x0x90000849b [System: PrevIdle DeclUser kDisp]
        """

        let start = SystemActivityLogParser.firstUserActivity(in: log, workDate: "2026-06-15")

        let expected = try XCTUnwrap(DateComponents(
            calendar: Calendar.gregorianSeoul,
            timeZone: TimeZone(identifier: "Asia/Seoul"),
            year: 2026,
            month: 6,
            day: 15,
            hour: 9,
            minute: 19,
            second: 10
        ).date)
        XCTAssertEqual(start, expected)
    }

    func testIgnoresSummaryOnlyUserActivityLines() {
        let log = """
        2026-06-15 06:27:45 +0900 Assertions           PID 659(WindowServer) Summary UserIsActive "com.apple.iohideventsystem.queue.tickle serviceID:100001362 service:AppleUserHIDEventService product:QK ALICE eventType:3" 00:15:31  id:0x0x90000a59a [System: PrevIdle DeclUser kDisp]
        2026-06-15 07:12:13 +0900 Assertions           PID 659(WindowServer) TimedOut UserIsActive "com.apple.iohideventsystem.queue.tickle serviceID:100001362 service:AppleUserHIDEventService product:QK ALICE eventType:3" 00:59:59  id:0x0x90000a59a [System: PrevIdle DeclUser kDisp]
        """

        XCTAssertNil(SystemActivityLogParser.firstUserActivity(in: log, workDate: "2026-06-15"))
    }
}

private extension Calendar {
    static var gregorianSeoul: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }
}
