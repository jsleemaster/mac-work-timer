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
    private var generationTracker = RefreshGenerationTracker()
    private var activeGeneration: RefreshGeneration?
    private var activeWeekStart: String?

    func refresh(weekStart: String, completion: @escaping (GWWeeklyProbeResult) -> Void) {
        cancelCurrentProbe()
        let generation = generationTracker.begin()
        activeGeneration = generation
        activeWeekStart = weekStart
        self.completion = completion
        didComplete = false

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView

        webView.load(URLRequest(url: GWConfiguration.bizboxURL))
        timeoutTask = Task { @MainActor [weak self, weak webView] in
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled, let self, let webView else { return }
            self.complete(
                .failure("이번 주 근태 조회 시간이 초과되었습니다."),
                generation: generation,
                webView: webView
            )
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let generation = activeGeneration,
              let weekStart = activeWeekStart,
              isCurrent(generation: generation, webView: webView),
              discoveryTask == nil else { return }
        discoveryTask = Task { @MainActor [weak self, weak webView] in
            guard let self, let webView else { return }
            await discoverWeeklyTable(
                in: webView,
                weekStart: weekStart,
                generation: generation
            )
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard let generation = activeGeneration else { return }
        complete(.failure(error.localizedDescription), generation: generation, webView: webView)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard let generation = activeGeneration else { return }
        complete(.failure(error.localizedDescription), generation: generation, webView: webView)
    }

    private func discoverWeeklyTable(
        in webView: WKWebView,
        weekStart: String,
        generation: RefreshGeneration
    ) async {
        let menuLabels = ["인사/근태", "근태관리", "개인근태현황"]

        for label in menuLabels {
            var didClick = false
            for _ in 0..<4 {
                if let records = await records(in: webView, weekStart: weekStart), !records.isEmpty {
                    complete(.success(records), generation: generation, webView: webView)
                    return
                }
                let result = try? await webView.evaluateJavaScript(GWWebMenuClickScript.make(label: label))
                if result as? Bool == true {
                    didClick = true
                    break
                }
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled, isCurrent(generation: generation, webView: webView) else { return }
            }
            if didClick {
                try? await Task.sleep(for: .milliseconds(900))
            }
            guard !Task.isCancelled, isCurrent(generation: generation, webView: webView) else { return }
        }

        for _ in 0..<6 {
            if let records = await records(in: webView, weekStart: weekStart), !records.isEmpty {
                complete(.success(records), generation: generation, webView: webView)
                return
            }
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled, isCurrent(generation: generation, webView: webView) else { return }
        }

        complete(
            .failure("개인근태현황 표를 찾지 못했습니다."),
            generation: generation,
            webView: webView
        )
    }

    private func records(in webView: WKWebView, weekStart: String) async -> [WeeklyAttendanceRecord]? {
        guard let value = try? await webView.evaluateJavaScript(Self.collectBodyText),
              let text = value as? String else {
            return nil
        }
        let records = parser.parse(text).filter { $0.workDate >= weekStart }
        return records.isEmpty ? nil : records
    }

    private func complete(
        _ result: GWWeeklyProbeResult,
        generation: RefreshGeneration,
        webView completedWebView: WKWebView
    ) {
        guard !didComplete,
              isCurrent(generation: generation, webView: completedWebView) else { return }
        didComplete = true
        generationTracker.invalidate()
        activeGeneration = nil
        activeWeekStart = nil
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
        generationTracker.invalidate()
        activeGeneration = nil
        activeWeekStart = nil
        timeoutTask?.cancel()
        discoveryTask?.cancel()
        timeoutTask = nil
        discoveryTask = nil
        webView?.navigationDelegate = nil
        webView?.stopLoading()
        webView = nil
        completion = nil
    }

    private func isCurrent(generation: RefreshGeneration, webView candidate: WKWebView) -> Bool {
        generationTracker.isCurrent(generation) && candidate === webView
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

}
