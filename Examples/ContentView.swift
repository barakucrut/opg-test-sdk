import SwiftUI
import WebKit

struct ContentView: View {

    @StateObject private var webViewStore: WebViewStore

    @State private var isLoading = false
    @State private var showWebView = false
    @State private var paymentIntent: PaymentIntent?

    init() {
        let controller = WKUserContentController()
        controller.add(OjireMessageProxy(), name: "Ojire")

        let config = WKWebViewConfiguration()
        config.userContentController = controller

        _webViewStore = StateObject(
            wrappedValue: WebViewStore(configuration: config)
        )
    }

    var body: some View {
        ZStack {
            if showWebView, let intent = paymentIntent {
                OjireWebView(
                    url: URL(string: "https://pay-dev.ojire.com/pay/\(intent.id)")!,
//                    url: URL(string: "http://43.157.203.153/test.html")!,
                    clientSecret: intent.clientSecret,
                    publicKey: "pk_177000551040616e1a131770005510406184b2479ad7758400e1",
                    token: intent.customerToken
                )
                .edgesIgnoringSafeArea(.all)
            } else {
                VStack(spacing: 16) {
                    Button(action: handleCheckout) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Pay Now")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(12)
                    .disabled(isLoading)
                }
                .padding()
            }
        }
    }

    // MARK: - Checkout API
    func handleCheckout() {
        isLoading = true

        guard let url = URL(string: "https://api-sandbox.ojire.com/v1/payment-intents") else {
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(
            "sk_177000551040616e1a1317700055104061700600ce2cc82a0e0e",
            forHTTPHeaderField: "X-Secret-Key"
        )

        let body: [String: Any] = [
            "amount": 7499000,
            "currency": "IDR",
            "merchantId": "55f85496-643b-4181-9d8f-22e7ee7c7c88",
            "customerId": "customer_test_123",
            "description": "Test payment",
            "metadata": [
                "orderId": "order_456"
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                isLoading = false
            }

            if let error = error {
                print("❌ Checkout error:", error)
                return
            }

            guard let data = data else { return }

            do {
                let intent = try JSONDecoder().decode(PaymentIntent.self, from: data)

                DispatchQueue.main.async {
                    self.paymentIntent = intent
                    self.showWebView = true
                }
            } catch {
                print("❌ Decode error:", error)
            }
        }.resume()
    }
}
