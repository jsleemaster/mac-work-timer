import SwiftUI
import WebKit

struct GWWebLoginView: NSViewRepresentable {
    let onAttendanceText: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onAttendanceText: onAttendanceText)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: URL(string: "https://gw.example.com/gw/bizbox.do")!))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onAttendanceText: (String) -> Void

        init(onAttendanceText: @escaping (String) -> Void) {
            self.onAttendanceText = onAttendanceText
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.body ? document.body.innerText : ''") { [weak self] result, _ in
                guard let text = result as? String, text.contains("출근") else {
                    return
                }
                DispatchQueue.main.async {
                    self?.onAttendanceText(text)
                }
            }
        }
    }
}
