import WebKit

public final class OjireMessageProxy: NSObject, WKScriptMessageHandler {

    public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        print("📩 JS MESSAGE:", message.body)
    }
}
