import XCTest
@testable import LimelinkIOSSDK

class LimeLinkTestCase: XCTestCase {
    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(MockURLProtocol.self)
        MockURLProtocol.reset()
        LimeLinkSDK.shared.resetForTesting()
        UserDefaults.standard.removeObject(forKey: "is_first_launch")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "is_first_launch")
        LimeLinkSDK.shared.resetForTesting()
        MockURLProtocol.reset()
        URLProtocol.unregisterClass(MockURLProtocol.self)
        super.tearDown()
    }

    func initializeSDK(
        apiKey: String = TestConstants.testApiKey,
        baseUrl: String = TestConstants.testBaseUrl,
        loggingEnabled: Bool = false,
        deferredDeeplinkEnabled: Bool = false
    ) {
        let config = LimeLinkConfig(
            apiKey: apiKey,
            baseUrl: baseUrl,
            loggingEnabled: loggingEnabled,
            deferredDeeplinkEnabled: deferredDeeplinkEnabled
        )
        LimeLinkSDK.initialize(config: config)
    }
}
