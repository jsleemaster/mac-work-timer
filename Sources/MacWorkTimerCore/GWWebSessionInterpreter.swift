import Foundation

public enum GWWebSessionInterpreter {
    public static func status(from text: String) -> GWStatus {
        if let record = AttendanceRecordParser.parse(text) {
            return .attendance(record)
        }

        if looksLikeLoginPage(text) {
            return .requiresWebLogin("GW 웹 로그인이 필요합니다.")
        }

        return .requiresWebLogin("출근 기록을 찾지 못했습니다. GW 웹 로그인이 필요합니다.")
    }

    private static func looksLikeLoginPage(_ text: String) -> Bool {
        let compactText = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return compactText.contains("아이디") && (compactText.contains("비밀번호") || compactText.contains("패스워드"))
    }
}
