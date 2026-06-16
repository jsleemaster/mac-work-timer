import Foundation

public protocol GWCredentialProviding: Sendable {
    func loadCredentials() throws -> GWCredentials?
}

public protocol GWTransporting: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

public struct URLSessionGWTransport: GWTransporting {
    public init() {}

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await URLSession.shared.data(for: request)
    }
}

public struct GWClient: Sendable {
    private let baseURL: URL
    private let credentialStore: GWCredentialProviding
    private let transport: GWTransporting

    public init(
        baseURL: URL = URL(string: "https://gw.example.com")!,
        credentialStore: GWCredentialProviding,
        transport: GWTransporting = URLSessionGWTransport()
    ) {
        self.baseURL = baseURL
        self.credentialStore = credentialStore
        self.transport = transport
    }

    public func refreshTodayStatus() async -> GWStatus {
        do {
            guard let credentials = try credentialStore.loadCredentials() else {
                return .notConfigured
            }

            return await refreshTodayStatus(credentials: credentials)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    public func refreshTodayStatus(credentials: GWCredentials) async -> GWStatus {
        do {
            let loginPageURL = makeURL(path: "/gw/uat/uia/egovLoginUsr.do")
            let (loginPageData, _) = try await requestData(URLRequest(url: loginPageURL), label: "로그인 페이지")
            let loginPageHTML = String(data: loginPageData, encoding: .utf8) ?? ""
            let actionPath = loginActionPath(from: loginPageHTML) ?? "/gw/uat/uia/actionLogin.do"

            let loginActionURL = URL(string: actionPath, relativeTo: baseURL)?.absoluteURL
                ?? makeURL(path: "/gw/uat/uia/actionLogin.do")
            var loginRequest = URLRequest(url: loginActionURL)
            loginRequest.httpMethod = "POST"
            loginRequest.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            loginRequest.httpBody = formBody([
                ("id", credentials.userID),
                ("password", credentials.password),
                ("isScLogin", ""),
                ("id_sub1", ""),
                ("id_sub2", "")
            ])

            let (loginData, loginResponse) = try await requestData(loginRequest, label: "로그인 요청")
            let loginHTML = String(data: loginData, encoding: .utf8) ?? ""

            if requiresWebLogin(html: loginHTML) {
                return .requiresWebLogin("2차 인증 또는 웹 로그인 확인이 필요합니다.")
            }

            if let httpResponse = loginResponse as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                return .failed("GW 로그인 요청 실패: HTTP \(httpResponse.statusCode)")
            }

            let portalURL = makeURL(path: "/gw/userMain.do", query: "isMain=Y")
            let (portalData, portalResponse) = try await requestData(URLRequest(url: portalURL), label: "포털 조회")

            if let httpResponse = portalResponse as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                return .failed("GW 포털 조회 실패: HTTP \(httpResponse.statusCode)")
            }

            let portalHTML = String(data: portalData, encoding: .utf8) ?? ""
            if let record = AttendanceRecordParser.parse(portalHTML) {
                return .attendance(record)
            }

            if let summary = attendanceSummary(from: portalHTML) {
                return .readOnlySummary(summary)
            }

            return .requiresWebLogin("근태 조회 화면은 웹 로그인에서 확인해야 합니다.")
        } catch {
            return .failed(Self.errorMessage(for: error, host: baseURL.host))
        }
    }

    private func requestData(_ request: URLRequest, label: String) async throws -> (Data, URLResponse) {
        do {
            return try await transport.data(for: request)
        } catch {
            throw GWClientError.requestFailed(label: label, url: request.url, underlying: error)
        }
    }

    private func makeURL(path: String, query: String? = nil) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = path
        components.query = query
        return components.url!
    }

    private func loginActionPath(from html: String) -> String? {
        let patterns = [
            #"<form\b[^>]*\baction\s*=\s*["']([^"']+)["']"#,
            #"\bloginForm\.action\s*=\s*["']([^"']+)["']"#
        ]

        for pattern in patterns {
            guard let action = firstMatch(in: html, pattern: pattern),
                  isUsableLoginAction(action) else {
                continue
            }

            return action
        }

        return nil
    }

    private func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let matchRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return String(text[matchRange])
    }

    private func isUsableLoginAction(_ action: String) -> Bool {
        if action.hasPrefix("/") {
            return true
        }

        guard let url = URL(string: action) else {
            return true
        }

        if url.scheme == nil {
            return true
        }

        return url.host != nil
    }

    private func requiresWebLogin(html: String) -> Bool {
        let lowered = html.lowercased()
        return lowered.contains("secondcert")
            || lowered.contains("login_v2")
            || lowered.contains("qr_view")
            || html.contains("이차인증")
            || html.contains("아이디 입력")
            || html.contains("패스워드 입력")
    }

    private func attendanceSummary(from html: String) -> String? {
        let text = html
            .replacingOccurrences(of: #"<script[\s\S]*?</script>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"<style[\s\S]*?</style>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard text.contains("출근") || text.contains("퇴근") || text.contains("근태") else {
            return nil
        }

        if text.count <= 120 {
            return text
        }

        let markers = ["오늘", "출근", "근태", "퇴근"]
        for marker in markers {
            if let range = text.range(of: marker) {
                let lower = text.index(range.lowerBound, offsetBy: -30, limitedBy: text.startIndex) ?? text.startIndex
                let upper = text.index(range.upperBound, offsetBy: 90, limitedBy: text.endIndex) ?? text.endIndex
                return String(text[lower..<upper]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return String(text.prefix(120))
    }

    private func normalizedText(from html: String) -> String {
        html
            .replacingOccurrences(of: #"<script[\s\S]*?</script>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"<style[\s\S]*?</style>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func formBody(_ pairs: [(String, String)]) -> Data {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._* ")
        let body = pairs
            .map { key, value in
                let escapedKey = key.addingPercentEncoding(withAllowedCharacters: allowed)?.replacingOccurrences(of: " ", with: "+") ?? key
                let escapedValue = value.addingPercentEncoding(withAllowedCharacters: allowed)?.replacingOccurrences(of: " ", with: "+") ?? value
                return "\(escapedKey)=\(escapedValue)"
            }
            .joined(separator: "&")
        return Data(body.utf8)
    }

    private static func errorMessage(for error: Error, host: String?) -> String {
        let nsError = error as NSError
        if let clientError = error as? GWClientError {
            return clientError.localizedDescription
        }

        let hostText = host ?? "unknown host"
        return "GW 조회 실패(\(hostText)): \(error.localizedDescription) [\(nsError.domain) \(nsError.code)]"
    }
}

private enum GWClientError: Error, LocalizedError {
    case requestFailed(label: String, url: URL?, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .requestFailed(let label, let url, let underlying):
            let nsError = underlying as NSError
            let host = url?.host ?? "unknown host"
            return "\(label) 실패(\(host)): \(underlying.localizedDescription) [\(nsError.domain) \(nsError.code)]"
        }
    }
}
