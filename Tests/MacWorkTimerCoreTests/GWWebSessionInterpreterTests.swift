import XCTest
@testable import MacWorkTimerCore

final class GWWebSessionInterpreterTests: XCTestCase {
    func testAttendanceTextCreatesAttendanceStatus() throws {
        let status = GWWebSessionInterpreter.status(from: "오늘 출근 2026.05.26 09:12:34 퇴근")

        let startAt = try XCTUnwrap(DateComponents(
            calendar: Calendar.gregorianSeoul,
            timeZone: TimeZone(identifier: "Asia/Seoul"),
            year: 2026,
            month: 5,
            day: 26,
            hour: 9,
            minute: 12,
            second: 34
        ).date)
        XCTAssertEqual(status, .attendance(AttendanceRecord(workDate: "2026-05-26", checkInAt: startAt, sourceText: "출근 2026.05.26 09:12:34")))
    }

    func testLoginPageTextRequiresWebLogin() {
        let status = GWWebSessionInterpreter.status(from: "아이디 비밀번호 로그인")

        XCTAssertEqual(status, .requiresWebLogin("GW 웹 로그인이 필요합니다."))
    }

    func testUnrecognizedTextRequiresWebLogin() {
        let status = GWWebSessionInterpreter.status(from: "Bizbox Alpha")

        XCTAssertEqual(status, .requiresWebLogin("출근 기록을 찾지 못했습니다. GW 웹 로그인이 필요합니다."))
    }
}

private extension Calendar {
    static var gregorianSeoul: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }
}
