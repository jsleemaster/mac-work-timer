import XCTest
@testable import MacWorkTimerCore

final class WeeklyAttendanceParserTests: XCTestCase {
    private let parser = WeeklyAttendanceParser()

    func testParsesCompletedAttendanceRowsFromTabbedBodyText() throws {
        let text = """
        일자\t요일\t출근시각\t출근등록방식\t퇴근시각\t퇴근등록방식\t근태항목\t근태구분
        2026-07-20\t월\t09:21\t세콤캡스연동\t18:44\t세콤캡스연동\t출퇴근\t정상
        2026-07-21\t화\t09:50\t세콤캡스연동\t18:36\t세콤캡스연동\t출퇴근\t정상
        """

        let records = parser.parse(text)

        XCTAssertEqual(records.count, 2)
        guard records.count == 2 else { return }
        XCTAssertEqual(records[0].workDate, "2026-07-20")
        XCTAssertEqual(records[0].kind, .attendance)
        XCTAssertEqual(records[0].checkInAt, try date("2026-07-20", "09:21"))
        XCTAssertEqual(records[0].checkOutAt, try date("2026-07-20", "18:44"))
    }

    func testParsesAttendanceAndAfternoonLeaveAsSeparateRecords() throws {
        let text = """
        2026-07-10\t금\t09:21\t세콤캡스연동\t14:23\t세콤캡스연동\t출퇴근\t정상
        2026-07-10\t금\t\t\t\t\t법정휴가\t오후반차
        """

        let records = parser.parse(text)

        XCTAssertEqual(records.count, 2)
        guard records.count == 2 else { return }
        XCTAssertEqual(records[0].checkOutAt, try date("2026-07-10", "14:23"))
        XCTAssertEqual(records[1].kind, .creditedLeave)
        XCTAssertEqual(records[1].creditedDuration, 4 * 60 * 60)
    }

    func testKeepsBlankCurrentCheckoutAndExplicitAbsence() throws {
        let text = """
        2026-07-22\t수\t09:35\t세콤캡스연동\t\t\t출퇴근\t출근
        2026-07-17\t금\t\t\t\t\t출퇴근\t결근
        """

        let records = parser.parse(text)

        XCTAssertEqual(records.count, 2)
        guard records.count == 2 else { return }
        XCTAssertEqual(records[0].checkInAt, try date("2026-07-22", "09:35"))
        XCTAssertNil(records[0].checkOutAt)
        XCTAssertEqual(records[1].kind, .explicitAbsence)
        XCTAssertEqual(records[1].creditedDuration, 0)
    }

    func testParsesHTMLTableRowsAndDeduplicatesIdenticalRows() {
        let html = """
        <table>
          <tr><th>일자</th><th>요일</th><th>출근시각</th><th>퇴근시각</th><th>근태구분</th></tr>
          <tr><td>2026-07-20</td><td>월</td><td>09:21</td><td>18:44</td><td>출퇴근</td><td>정상</td></tr>
          <tr><td>2026-07-20</td><td>월</td><td>09:21</td><td>18:44</td><td>출퇴근</td><td>정상</td></tr>
        </table>
        """

        let records = parser.parse(html)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.workDate, "2026-07-20")
    }

    func testIgnoresRowsWithMalformedTimes() {
        let text = "2026-07-20\t월\t29:71\t세콤캡스연동\t18:44\t세콤캡스연동\t출퇴근\t정상"

        XCTAssertTrue(parser.parse(text).isEmpty)
    }

    func testIgnoresUnrelatedCalendarRowsWithTwoTimes() {
        let text = "2026-07-20\t프로젝트 회의\t09:21\t18:44\t회의실 A"

        XCTAssertTrue(parser.parse(text).isEmpty)
    }

    func testParsesCellsSplitAcrossLinesBetweenDateBoundaries() throws {
        let text = """
        일자
        요일
        출근시각
        퇴근시각
        2026-07-20
        월
        09:21
        세콤캡스연동
        18:44
        세콤캡스연동
        출퇴근
        정상
        2026-07-21
        화
        09:50
        세콤캡스연동
        18:36
        세콤캡스연동
        출퇴근
        정상
        """

        let records = parser.parse(text)

        XCTAssertEqual(records.count, 2)
        guard records.count == 2 else { return }
        XCTAssertEqual(records[0].checkInAt, try date("2026-07-20", "09:21"))
        XCTAssertEqual(records[0].checkOutAt, try date("2026-07-20", "18:44"))
        XCTAssertEqual(records[1].checkInAt, try date("2026-07-21", "09:50"))
    }

    private func date(_ workDate: String, _ time: String) throws -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        return try XCTUnwrap(dateFormatter.date(from: "\(workDate) \(time)"))
    }
}
