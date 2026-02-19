import Foundation
@testable import LimelinkIOSSDK

struct TestConstants {
    // MARK: - Config
    static let testApiKey = "test-api-key-12345"
    static let testBaseUrl = "https://test.limelink.org/"

    static func makeConfig(
        apiKey: String = testApiKey,
        baseUrl: String = testBaseUrl,
        loggingEnabled: Bool = false,
        deferredDeeplinkEnabled: Bool = false
    ) -> LimeLinkConfig {
        return LimeLinkConfig(
            apiKey: apiKey,
            baseUrl: baseUrl,
            loggingEnabled: loggingEnabled,
            deferredDeeplinkEnabled: deferredDeeplinkEnabled
        )
    }

    // MARK: - URLs
    static let subdomainURL = URL(string: "https://abc.limelink.org/link/campaign123")!
    static let directURL = URL(string: "https://limelink.org/universal-link/app/dynamic_link/campaign123")!
    static let directAPIURL = URL(string: "https://limelink.org/api/v1/app/dynamic_link/campaign123")!
    static let legacyURL = URL(string: "https://custom.example.com/somepath")!
    static let subdomainNoLinkURL = URL(string: "https://abc.limelink.org/other/path")!

    static let schemeURL = URL(string: "myapp://open?original-url=https%3A%2F%2Fexample.com%2Fpage%3Fkey%3Dvalue")!
    static let schemeURLNoOriginal = URL(string: "myapp://open?other=param")!

    static let pathURL = URL(string: "https://example.com/main/sub/detail")!
    static let emptyPathURL = URL(string: "https://example.com")!

    // MARK: - JSON Responses
    static let universalLinkResponseJSON: Data = {
        return try! JSONEncoder().encode(["uri": "myapp://product/123"])
    }()

    static let universalLinkResponseURI = "myapp://product/123"

    static let deeplinkResponseJSON: Data = {
        return try! JSONEncoder().encode(["deeplinkUrl": "myapp://deeplink/abc"])
    }()

    static let suffixResponseJSON: Data = {
        return """
        {"suffix": "campaign123", "full_request_url": "https://abc.limelink.org/link/campaign123"}
        """.data(using: .utf8)!
    }()

    static let suffixResponseWithQueryParamsJSON: Data = {
        return """
        {"suffix": "campaign123", "full_request_url": "https://abc.limelink.org/link/campaign123?utm_source=google&product_id=789"}
        """.data(using: .utf8)!
    }()

    static let suffixResponseNoMatchJSON: Data = {
        return """
        {"suffix": null, "full_request_url": null}
        """.data(using: .utf8)!
    }()

    static let dynamicLinkResponseJSON: Data = {
        return try! JSONEncoder().encode(["uri": "myapp://deferred/456"])
    }()

    static let statsSuccessResponseJSON: Data = {
        return "{}".data(using: .utf8)!
    }()

    // MARK: - Helpers
    static func makeHTTPResponse(url: URL, statusCode: Int = 200, headers: [String: String]? = nil) -> HTTPURLResponse {
        return HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: headers)!
    }
}
