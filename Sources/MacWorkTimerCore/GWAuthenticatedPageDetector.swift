public enum GWAuthenticatedPageDetector {
    public static func isAuthenticated(urlPath: String?, bodyText: String) -> Bool {
        switch urlPath {
        case "/gw/userMain.do":
            return true
        case "/gw/bizbox.do":
            return bodyText.contains("인사/근태")
        default:
            return false
        }
    }
}
