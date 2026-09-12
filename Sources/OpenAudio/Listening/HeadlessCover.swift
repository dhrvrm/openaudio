import WebKit

@MainActor
final class HeadlessCover: NSObject, WKNavigationDelegate, WKUIDelegate {
    private var failure: Error?
    private var finished = false
    private var navigation: WKNavigation?
    private var evaluationID = UUID()
    private var evaluation: CheckedContinuation<String, Error>?
    private var evaluationTimeout: Task<Void, Never>?
    private var webView: WKWebView?

    static func find(_ track: MediaTrack, budget: CoverDownloadBudget) async throws -> CoverCacheEntry {
        let reader = HeadlessCover()
        return try await reader.find(track, budget: budget)
    }
    private func find(_ track: MediaTrack, budget: CoverDownloadBudget) async throws -> CoverCacheEntry {
        guard let scriptURL = Bundle.main.url(forResource: "CoverPage", withExtension: "js") else {
            throw NSError(domain: "OpenAudio", code: 1, userInfo: [NSLocalizedDescriptionKey: "Public-page cover lookup is unavailable in this build."])
        }
        let script = try String(contentsOf: scriptURL, encoding: .utf8)
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        let rules = try await WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "OpenAudioCoverReader", encodedContentRuleList: "[{\"trigger\":{\"url-filter\":\".*\",\"resource-type\":[\"image\",\"media\",\"font\",\"ping\"]},\"action\":{\"type\":\"block\"}}]")
        if let rules { configuration.userContentController.add(rules) }
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 640, height: 480), configuration: configuration)
        webView = view
        view.navigationDelegate = self; view.uiDelegate = self
        await view.setAllMediaPlaybackSuspended(true)
        defer { view.stopLoading(); view.navigationDelegate = nil; view.uiDelegate = nil; webView = nil }
        let discovery = try await read(HeadlessCoverPolicy.search(track), script: script, view: view)
        let pages = Array(Set(discovery.links.compactMap(HeadlessCoverPolicy.page))).sorted { $0.absoluteString < $1.absoluteString }.prefix(2)
        guard !pages.isEmpty else { throw NSError(domain: "OpenAudio", code: 2, userInfo: [NSLocalizedDescriptionKey: "Public search returned no readable music pages. It may be blocked; try again later."]) }
        var pageError: Error?
        for page in pages {
            try Task.checkCancellation()
            do {
                let snapshot = try await read(page, script: script, view: view)
                let suggestion = HeadlessCoverPolicy.suggestion(snapshot, track: track)
                if let image = suggestion?.images.compactMap(MediaURL.allowed).first ?? HeadlessCoverPolicy.image(snapshot, track: track) {
                    let downloaded = try await budget.fetch(image)
                    guard let bytes = try await CoverQuality.prepareAsync(downloaded) else { throw URLError(.cannotDecodeContentData) }
                    let attribution = suggestion.map { "Suggested artwork · \($0.artist) — \($0.album) · \(page.host ?? "music page")" } ?? "Cover matched on \(page.host ?? "music page") · \(track.artist) — \(track.title)"
                    return CoverCacheEntry(created: Date().timeIntervalSince1970, image: bytes, attribution: attribution, suggested: suggestion != nil)
                }
                if snapshot.items.isEmpty { pageError = URLError(.cannotParseResponse) }
            } catch is CancellationError { throw CancellationError() }
            catch { pageError = error }
        }
        if let pageError { throw pageError }
        return CoverCacheEntry(created: Date().timeIntervalSince1970, attribution: "No verified cover matched this title, artist and album.")
    }
    private func read(_ url: URL, script: String, view: WKWebView) async throws -> CoverPageSnapshot {
        failure = nil; finished = false
        navigation = view.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 6))
        let deadline = Date().addingTimeInterval(7)
        while !finished && failure == nil {
            try Task.checkCancellation()
            guard Date() < deadline else { view.stopLoading(); throw URLError(.timedOut) }
            try await Task.sleep(for: .milliseconds(100))
        }
        if let failure { throw failure }
        try await Task.sleep(for: .milliseconds(600))
        try Task.checkCancellation()
        let text = try await evaluate(script, view: view)
        return try JSONDecoder().decode(CoverPageSnapshot.self, from: Data(text.utf8))
    }
    private func evaluate(_ script: String, view: WKWebView) async throws -> String {
        try Task.checkCancellation()
        let id = UUID()
        evaluationID = id
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                evaluation = continuation
                evaluationTimeout = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(2)) } catch { return }
                    self?.finishEvaluation(.failure(URLError(.timedOut)), id: id)
                }
                view.evaluateJavaScript(script) { [weak self] result, error in
                    if let error { self?.finishEvaluation(.failure(error), id: id) }
                    else if let text = result as? String, text.utf8.count < 262144 { self?.finishEvaluation(.success(text), id: id) }
                    else { self?.finishEvaluation(.failure(URLError(.cannotParseResponse)), id: id) }
                }
            }
        } onCancel: { Task { @MainActor [weak self] in self?.finishEvaluation(.failure(CancellationError()), id: id) } }
    }
    private func finishEvaluation(_ result: Result<String, Error>, id: UUID) {
        guard evaluationID == id else { return }
        let continuation = evaluation; evaluation = nil
        evaluationTimeout?.cancel(); evaluationTimeout = nil
        continuation?.resume(with: result)
    }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let allowed = action.targetFrame?.isMainFrame == true && action.request.url.map(HeadlessCoverPolicy.navigation) == true
        if !allowed && action.targetFrame?.isMainFrame == true { failure = URLError(.redirectToNonExistentLocation) }
        decisionHandler(allowed ? .allow : .cancel)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { if navigation === self.navigation { finished = true } }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { if navigation === self.navigation { failure = error } }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { if navigation === self.navigation { failure = error } }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { failure = URLError(.networkConnectionLost) }
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust ? .performDefaultHandling : .cancelAuthenticationChallenge, nil)
    }
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) { decisionHandler(.deny) }
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) { completionHandler() }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) { completionHandler(false) }
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) { completionHandler(nil) }
}
