import MacWorkTimerCore
import WebKit

enum GWWeeklyProbeResult {
    case success([WeeklyAttendanceRecord])
    case failure(String)
}

@MainActor
final class GWWeeklyWebSessionProbe: NSObject, WKNavigationDelegate {
    private let parser = WeeklyAttendanceParser()
    private var webView: WKWebView?
    private var completion: ((GWWeeklyProbeResult) -> Void)?
    private var discoveryTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var didComplete = false
    private var requestedWeekStart = ""

    func refresh(weekStart: String, completion: @escaping (GWWeeklyProbeResult) -> Void) {
        cancelCurrentProbe()
        self.completion = completion
        didComplete = false
        requestedWeekStart = weekStart

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView

        webView.load(URLRequest(url: GWConfiguration.bizboxURL))
        timeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled else { return }
            self?.complete(.failure("이번 주 근태 조회 시간이 초과되었습니다."))
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard discoveryTask == nil else { return }
        discoveryTask = Task { @MainActor [weak self, weak webView] in
            guard let self, let webView else { return }
            await discoverWeeklyTable(in: webView)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        complete(.failure(error.localizedDescription))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        complete(.failure(error.localizedDescription))
    }

    private func discoverWeeklyTable(in webView: WKWebView) async {
        let menuLabels = ["인사/근태", "근태관리", "개인근태현황"]

        for label in menuLabels {
            if let records = await records(in: webView), !records.isEmpty {
                complete(.success(records))
                return
            }
            _ = try? await webView.evaluateJavaScript(Self.clickScript(label: label))
            try? await Task.sleep(for: .milliseconds(850))
            guard !Task.isCancelled, !didComplete else { return }
        }

        for _ in 0..<6 {
            if let records = await records(in: webView), !records.isEmpty {
                complete(.success(records))
                return
            }
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled, !didComplete else { return }
        }

        complete(.failure("개인근태현황 표를 찾지 못했습니다."))
    }

    private func records(in webView: WKWebView) async -> [WeeklyAttendanceRecord]? {
        guard let value = try? await webView.evaluateJavaScript(Self.collectBodyText),
              let text = value as? String else {
            return nil
        }
        let records = parser.parse(text).filter { $0.workDate >= requestedWeekStart }
        return records.isEmpty ? nil : records
    }

    private func complete(_ result: GWWeeklyProbeResult) {
        guard !didComplete else { return }
        didComplete = true
        timeoutTask?.cancel()
        timeoutTask = nil
        discoveryTask?.cancel()
        discoveryTask = nil
        let completion = completion
        self.completion = nil
        webView?.navigationDelegate = nil
        webView?.stopLoading()
        webView = nil
        completion?(result)
    }

    private func cancelCurrentProbe() {
        timeoutTask?.cancel()
        discoveryTask?.cancel()
        timeoutTask = nil
        discoveryTask = nil
        webView?.navigationDelegate = nil
        webView?.stopLoading()
        webView = nil
        completion = nil
    }

    private static let collectBodyText = #"""
    (() => {
      const chunks = [];
      const visit = (win) => {
        try {
          if (win.document.body && win.document.body.innerText) {
            chunks.push(win.document.body.innerText);
          }
          for (let index = 0; index < win.frames.length; index += 1) {
            visit(win.frames[index]);
          }
        } catch (_) {}
      };
      visit(window);
      return chunks.join('\n');
    })()
    """#

    private static func clickScript(label: String) -> String {
        let encodedLabel = label
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        return #"""
        (() => {
          const wanted = 'LABEL';
          const visit = (win) => {
            try {
              const elements = Array.from(win.document.querySelectorAll('a, button, [role="menuitem"], li, span'));
              const match = elements.find((element) => {
                const text = (element.textContent || '').replace(/\s+/g, ' ').trim();
                const rect = element.getBoundingClientRect();
                return text === wanted && rect.width > 0 && rect.height > 0;
              });
              if (match) {
                const clickable = match.closest('a, button, [role="menuitem"]') || match;
                clickable.click();
                return true;
              }
              for (let index = 0; index < win.frames.length; index += 1) {
                if (visit(win.frames[index])) return true;
              }
            } catch (_) {}
            return false;
          };
          return visit(window);
        })()
        """#.replacingOccurrences(of: "LABEL", with: encodedLabel)
    }
}
