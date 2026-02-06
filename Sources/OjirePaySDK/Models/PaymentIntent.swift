import Foundation

public struct PaymentIntent: Codable {
    public let id: String
    public let clientSecret: String
    public let customerToken: String
}
