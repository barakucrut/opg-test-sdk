import SwiftUI
@preconcurrency import WebKit

public struct OjireWebView: UIViewRepresentable {

    // MARK: - Public Params
    public let id: String
    public let clientSecret: String
    public let publicKey: String
    public let token: String

    public var onSuccess: (([String: Any]) -> Void)?
    public var onPending: (([String: Any]) -> Void)?
    public var onFailed: (([String: Any]) -> Void)?
    public var onClose: (() -> Void)?

    // MARK: - Init
    public init(
        id: String,
        clientSecret: String,
        publicKey: String,
        token: String,
        onSuccess: (([String: Any]) -> Void)? = nil,
        onPending: (([String: Any]) -> Void)? = nil,
        onFailed: (([String: Any]) -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.id = id
        self.clientSecret = clientSecret
        self.publicKey = publicKey
        self.token = token
        self.onSuccess = onSuccess
        self.onPending = onPending
        self.onFailed = onFailed
        self.onClose = onClose
    }

    // MARK: - UIViewRepresentable
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIView(context: Context) -> WKWebView {

        let config = WKWebViewConfiguration()

        // ✅ Enable JavaScript
        let pagePrefs = WKWebpagePreferences()
        pagePrefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = pagePrefs

        // ✅ Disable cache
        config.websiteDataStore = .nonPersistent()

        // ✅ Web → iOS bridge
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "Ojire")
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        let url = URL(string: "https://pay-dev.ojire.com/pay/\(id)")!
        webView.load(URLRequest(url: url))

        context.coordinator.webView = webView
        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {}

    // MARK: - Coordinator
    public final class Coordinator: NSObject,
                                    WKNavigationDelegate,
                                    WKUIDelegate,
                                    WKScriptMessageHandler {

        let parent: OjireWebView
        weak var webView: WKWebView?
        private var didSendInit = false

        init(_ parent: OjireWebView) {
            self.parent = parent
        }

        // MARK: - Web → iOS (READY)
        public func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard
                message.name == "Ojire",
                let body = message.body as? [String: Any],
                let type = body["type"] as? String
            else { return }

            print("📩 WEB → IOS:", body)

            if type == "READY" {
                sendInitIfNeeded()
            }
        }

        // MARK: - iOS → Web (INIT)
        private func sendInitIfNeeded() {
            guard let webView, !didSendInit else { return }
            didSendInit = true

            let payload: [String: Any] = [
                "type": "INIT",
                "clientSecret": parent.clientSecret,
                "publicKey": parent.publicKey,
                "token": parent.token
            ]

            guard
                let data = try? JSONSerialization.data(withJSONObject: payload),
                let json = String(data: data, encoding: .utf8)
            else { return }

            let js = """
            if (window.__OJIRE_INIT__) {
                window.__OJIRE_INIT__(\(json));
            }
            true;
            """

            print("📤 IOS → WEB INIT")
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        // MARK: - URL JOURNEY (RESULT)
        public func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            let urlString = url.absoluteString
            print("🌍 NAV:", urlString)

            let params = parseQuery(url)

            if urlString.contains("status=success") {
                parent.onSuccess?(params)
                decisionHandler(.cancel)
                return
            }

            if urlString.contains("status=pending") {
                parent.onPending?(params)
                decisionHandler(.cancel)
                return
            }

            if urlString.contains("status=failed") {
                parent.onFailed?(params)
                decisionHandler(.cancel)
                return
            }

            if urlString.contains("action=close") {
                parent.onClose?()
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        // MARK: - JS Alert Support
        public func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping () -> Void
        ) {
            let alert = UIAlertController(
                title: "Alert",
                message: message,
                preferredStyle: .alert
            )
            alert.addAction(
                UIAlertAction(title: "OK", style: .default) { _ in
                    completionHandler()
                }
            )

            UIApplication.shared
                .connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?
                .rootViewController?
                .present(alert, animated: true)
        }

        // MARK: - Helpers
        private func parseQuery(_ url: URL) -> [String: Any] {
            var result: [String: Any] = [:]

            URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .forEach { result[$0.name] = $0.value }

            return result
        }
    }
}
