import XCTest
@testable import LimelinkIOSSDK

class LimeLinkConfigTests: XCTestCase {

    func test_defaultBaseUrl() {
        let config = LimeLinkConfig(apiKey: "key")
        XCTAssertEqual(config.baseUrl, "https://limelink.org/")
    }

    func test_customBaseUrl() {
        let config = LimeLinkConfig(apiKey: "key", baseUrl: "https://custom.example.com/")
        XCTAssertEqual(config.baseUrl, "https://custom.example.com/")
    }

    func test_baseUrlTrailingSlashAppended() {
        let config = LimeLinkConfig(apiKey: "key", baseUrl: "https://test.com")
        XCTAssertEqual(config.baseUrl, "https://test.com/")
    }

    func test_baseUrlWithTrailingSlashUnchanged() {
        let config = LimeLinkConfig(apiKey: "key", baseUrl: "https://test.com/")
        XCTAssertEqual(config.baseUrl, "https://test.com/")
    }

    func test_apiKeyStored() {
        let config = LimeLinkConfig(apiKey: "my-secret-key")
        XCTAssertEqual(config.apiKey, "my-secret-key")
    }
}
