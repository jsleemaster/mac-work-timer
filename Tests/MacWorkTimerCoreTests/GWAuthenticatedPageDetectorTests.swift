import XCTest
@testable import MacWorkTimerCore

final class GWAuthenticatedPageDetectorTests: XCTestCase {
    func testUserMainIsAuthenticatedWithoutTodayAttendanceText() {
        XCTAssertTrue(
            GWAuthenticatedPageDetector.isAuthenticated(
                urlPath: "/gw/userMain.do",
                bodyText: "전자결재 일정 인사/근태"
            )
        )
    }

    func testBizboxShellIsAuthenticated() {
        XCTAssertTrue(
            GWAuthenticatedPageDetector.isAuthenticated(
                urlPath: "/gw/bizbox.do",
                bodyText: "인사/근태 근태관리 개인근태현황"
            )
        )
    }

    func testLoginPageIsNotAuthenticated() {
        XCTAssertFalse(
            GWAuthenticatedPageDetector.isAuthenticated(
                urlPath: "/gw/uat/uia/egovLoginUsr.do",
                bodyText: "아이디 비밀번호 로그인"
            )
        )
    }
}
