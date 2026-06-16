import XCTest
@testable import MacWorkTimerCore

final class GWClientTests: XCTestCase {
    func testMissingCredentialsReturnsNotConfiguredWithoutNetwork() async throws {
        let client = GWClient(
            baseURL: URL(string: "https://gw.example.com")!,
            credentialStore: InMemoryCredentialStore(credentials: nil),
            transport: RecordingGWTransport()
        )

        let status = await client.refreshTodayStatus()

        XCTAssertEqual(status, .notConfigured)
    }

    func testLoginPageWithSecondCertFallsBackToWebLogin() async throws {
        let transport = RecordingGWTransport(responses: [
            (HTTPURLResponse.fixture(url: "https://gw.example.com/gw/uat/uia/egovLoginUsr.do", statusCode: 200), Data("<form action=\"/gw/uat/uia/actionLogin.do\"></form>".utf8)),
            (HTTPURLResponse.fixture(url: "https://gw.example.com/gw/uat/uia/actionLogin.do", statusCode: 200), Data("<div class=\"secondCert\">이차인증</div>".utf8))
        ])
        let client = GWClient(
            baseURL: URL(string: "https://gw.example.com")!,
            credentialStore: InMemoryCredentialStore(credentials: GWCredentials(userID: "u", password: "p")),
            transport: transport
        )

        let status = await client.refreshTodayStatus()

        XCTAssertEqual(status, .requiresWebLogin("2차 인증 또는 웹 로그인 확인이 필요합니다."))
        XCTAssertEqual(transport.requests.map(\.url?.path), ["/gw/uat/uia/egovLoginUsr.do", "/gw/uat/uia/actionLogin.do"])
    }

    func testPortalHtmlAttendanceRecordCreatesWorkSession() async throws {
        let transport = RecordingGWTransport(responses: [
            (HTTPURLResponse.fixture(url: "https://gw.example.com/gw/uat/uia/egovLoginUsr.do", statusCode: 200), Data("<form action=\"/gw/uat/uia/actionLogin.do\"></form>".utf8)),
            (HTTPURLResponse.fixture(url: "https://gw.example.com/gw/uat/uia/actionLogin.do", statusCode: 302), Data()),
            (HTTPURLResponse.fixture(url: "https://gw.example.com/gw/userMain.do?isMain=Y", statusCode: 200), Data("<html><body>User 출근 2026.05.19 09:25:07 퇴근</body></html>".utf8))
        ])
        let client = GWClient(
            baseURL: URL(string: "https://gw.example.com")!,
            credentialStore: InMemoryCredentialStore(credentials: GWCredentials(userID: "u", password: "p")),
            transport: transport
        )

        let status = await client.refreshTodayStatus()

        let startAt = try XCTUnwrap(DateComponents(
            calendar: Calendar.gregorianSeoul,
            timeZone: TimeZone(identifier: "Asia/Seoul"),
            year: 2026,
            month: 5,
            day: 19,
            hour: 9,
            minute: 25,
            second: 7
        ).date)
        XCTAssertEqual(status, .attendance(AttendanceRecord(workDate: "2026-05-19", checkInAt: startAt, sourceText: "출근 2026.05.19 09:25:07")))
    }

    func testLoginActionIgnoresJavascriptAssignmentsBeforeFormAction() async throws {
        let loginPageHTML = """
        <script>
        document.loginForm.action="https://"+serverName+":"+port+"/gw/uat/uia/actionLogin.do";
        </script>
        <form name="loginForm" action ="/gw/uat/uia/actionLogin.do" method="post"></form>
        """
        let transport = RecordingGWTransport(responses: [
            (HTTPURLResponse.fixture(url: "https://gw.example.com/gw/uat/uia/egovLoginUsr.do", statusCode: 200), Data(loginPageHTML.utf8)),
            (HTTPURLResponse.fixture(url: "https://gw.example.com/gw/uat/uia/actionLogin.do", statusCode: 200), Data("<div class=\"secondCert\">이차인증</div>".utf8))
        ])
        let client = GWClient(
            baseURL: URL(string: "https://gw.example.com")!,
            credentialStore: InMemoryCredentialStore(credentials: GWCredentials(userID: "u", password: "p")),
            transport: transport
        )

        _ = await client.refreshTodayStatus()

        XCTAssertEqual(transport.requests.map(\.url?.absoluteString), [
            "https://gw.example.com/gw/uat/uia/egovLoginUsr.do",
            "https://gw.example.com/gw/uat/uia/actionLogin.do"
        ])
    }
}

private final class InMemoryCredentialStore: GWCredentialProviding, @unchecked Sendable {
    let credentials: GWCredentials?

    init(credentials: GWCredentials?) {
        self.credentials = credentials
    }

    func loadCredentials() throws -> GWCredentials? {
        credentials
    }
}

private extension Calendar {
    static var gregorianSeoul: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }
}

private final class RecordingGWTransport: GWTransporting, @unchecked Sendable {
    private let responses: [(HTTPURLResponse, Data)]
    private(set) var requests: [URLRequest] = []

    init(responses: [(HTTPURLResponse, Data)] = []) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        guard requests.count <= responses.count else {
            throw URLError(.badServerResponse)
        }
        let (response, data) = responses[requests.count - 1]
        return (data, response)
    }
}

private extension HTTPURLResponse {
    static func fixture(url: String, statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: url)!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    }
}
