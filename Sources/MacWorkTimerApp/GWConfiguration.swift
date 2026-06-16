import Foundation

enum GWConfiguration {
    private static let defaultBaseURL = URL(string: "https://gw.example.com")!
    private static let baseURLDefaultsKey = "GWBaseURL"

    static var baseURL: URL {
        guard let value = UserDefaults.standard.string(forKey: baseURLDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty,
            let url = URL(string: value),
            url.scheme != nil,
            url.host != nil else {
            return defaultBaseURL
        }

        return url
    }

    static var credentialAccount: String {
        baseURL.host ?? defaultBaseURL.host ?? "gw.example.com"
    }

    static var bizboxURL: URL {
        baseURL.appending(path: "gw/bizbox.do")
    }

    static var userMainURL: URL {
        baseURL.appending(path: "gw/userMain.do")
            .appending(queryItems: [URLQueryItem(name: "isMain", value: "Y")])
    }
}
