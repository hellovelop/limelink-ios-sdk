import XCTest
@testable import LimelinkIOSSDK

class ObjCBridgeTests: LimeLinkTestCase {

    // MARK: - Bridge class existence

    func test_bridge_classExists() {
        let bridgeClass: AnyClass? = NSClassFromString("UniversalLinkHandlerBridge")
        XCTAssertNotNil(bridgeClass, "UniversalLinkHandlerBridge class should exist")
    }

    // MARK: - Bridge completion handler via UniversalLink

    func test_bridge_completionHandler() {
        initializeSDK()
        let exp = expectation(description: "completion")

        MockURLProtocol.requestHandlers["dynamic_link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.universalLinkResponseJSON)
        }

        // Test completion-based variant via UniversalLink directly
        // (since ObjC class method selectors are harder to call from Swift)
        let url = URL(string: "https://limelink.org/universal-link/app/dynamic_link/test")!
        UniversalLink.shared.handleUniversalLink(url) { uri in
            XCTAssertEqual(uri, TestConstants.universalLinkResponseURI)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    // MARK: - SDK handleUniversalLink (bridge target)

    func test_bridge_sdkInitialized_handleUniversalLinkWorks() {
        initializeSDK()
        let listener = MockLimeLinkListener()
        listener.onResultExpectation = expectation(description: "result")
        LimeLinkSDK.shared.addLinkListener(listener)

        MockURLProtocol.requestHandlers["dynamic_link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.universalLinkResponseJSON)
        }
        MockURLProtocol.requestHandlers["stats/event"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.statsSuccessResponseJSON)
        }

        // Call the same method the ObjC bridge would route to
        let url = URL(string: "https://limelink.org/universal-link/app/dynamic_link/test")!
        LimeLinkSDK.shared.handleUniversalLink(url)

        wait(for: [listener.onResultExpectation!], timeout: 5.0)
        XCTAssertEqual(listener.receivedResults.count, 1)
    }
}
