import WebKit
import Combine

public final class WebViewStore: ObservableObject {

    public let webView: WKWebView

    public init(configuration: WKWebViewConfiguration) {
        self.webView = WKWebView(frame: .zero, configuration: configuration)
    }
}
