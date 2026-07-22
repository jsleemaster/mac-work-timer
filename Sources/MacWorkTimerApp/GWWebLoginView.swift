import SwiftUI
import WebKit
import MacWorkTimerCore

struct GWWebLoginView: NSViewRepresentable {
    let onAuthenticatedSession: () -> Void
    let onAttendanceText: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onAuthenticatedSession: onAuthenticatedSession,
            onAttendanceText: onAttendanceText
        )
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: GWConfiguration.bizboxURL))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onAuthenticatedSession: () -> Void
        let onAttendanceText: (String) -> Void

        init(
            onAuthenticatedSession: @escaping () -> Void,
            onAttendanceText: @escaping (String) -> Void
        ) {
            self.onAuthenticatedSession = onAuthenticatedSession
            self.onAttendanceText = onAttendanceText
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.body ? document.body.innerText : ''") { [weak self] result, _ in
                guard let self, let text = result as? String else {
                    return
                }
                let isAuthenticated = GWAuthenticatedPageDetector.isAuthenticated(
                    urlPath: webView.url?.path,
                    bodyText: text
                )
                DispatchQueue.main.async {
                    if text.contains("출근") {
                        self.onAttendanceText(text)
                    }
                    if isAuthenticated {
                        self.onAuthenticatedSession()
                    }
                }
            }
        }
    }
}
