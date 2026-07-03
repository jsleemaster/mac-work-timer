import MacWorkTimerCore
import WebKit

@MainActor
final class GWWebSessionProbe: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var completion: ((GWStatus) -> Void)?
    private var timeoutTask: Task<Void, Never>?
    private var didComplete = false

    func refresh(completion: @escaping (GWStatus) -> Void) {
        timeoutTask?.cancel()
        webView?.stopLoading()
        webView?.navigationDelegate = nil

        self.completion = completion
        didComplete = false

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView

        webView.load(URLRequest(url: GWConfiguration.userMainURL))
        timeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(12))
            guard !Task.isCancelled else {
                return
            }

            self?.complete(with: .failed("GW 조회 시간이 초과되었습니다."))
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("document.body ? document.body.innerText : ''") { [weak self] result, _ in
            Task { @MainActor in
                guard let self, !self.didComplete else {
                    return
                }

                let text = result as? String ?? ""
                self.complete(with: GWWebSessionInterpreter.status(from: text))
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        complete(with: .failed(error.localizedDescription))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        complete(with: .failed(error.localizedDescription))
    }

    private func complete(with status: GWStatus) {
        guard !didComplete else {
            return
        }

        didComplete = true
        timeoutTask?.cancel()
        timeoutTask = nil
        let completion = completion
        self.completion = nil
        webView?.navigationDelegate = nil
        webView?.stopLoading()
        webView = nil
        completion?(status)
    }
}
