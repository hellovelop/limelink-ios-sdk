import XCTest
@testable import LimelinkIOSSDK

class UniversalLinkFlowTests: LimeLinkTestCase {

    // MARK: - Subdomain E2E

    func test_subdomainFlow_fullE2E() {
        initializeSDK()
        let listener = MockLimeLinkListener()
        listener.onResultExpectation = expectation(description: "result")
        LimeLinkSDK.shared.addLinkListener(listener)

        // HEAD request to abc.limelink.org for header collection
        // Use host-only pattern to avoid collision with full_request_url query param
        MockURLProtocol.requestHandlers["://abc.limelink.org"] = { request in
            return (TestConstants.makeHTTPResponse(url: request.url!, headers: ["X-Request-ID": "test"]), nil)
        }
        MockURLProtocol.requestHandlers["api/v1/app/dynamic_link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.universalLinkResponseJSON)
        }
        MockURLProtocol.requestHandlers["stats/event"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.statsSuccessResponseJSON)
        }

        let url = URL(string: "https://abc.limelink.org/link/campaign123")!
        LimeLinkSDK.shared.handleUniversalLink(url)

        wait(for: [listener.onResultExpectation!], timeout: 5.0)

        XCTAssertGreaterThanOrEqual(listener.receivedResults.count, 1)
        guard let result = listener.receivedResults.first else { return }
        XCTAssertEqual(result.resolvedUri, TestConstants.universalLinkResponseURI)
        XCTAssertFalse(result.isDeferred)
        XCTAssertEqual(result.originalUrl, url.absoluteString)

        // Verify stats POST
        let statsExp = expectation(description: "stats")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let statsRequests = MockURLProtocol.capturedRequests.filter {
                $0.url?.absoluteString.contains("stats/event") == true
            }
            XCTAssertGreaterThanOrEqual(statsRequests.count, 1)
            statsExp.fulfill()
        }
        wait(for: [statsExp], timeout: 3.0)
    }

    // MARK: - Direct Access E2E

    func test_directAccessFlow_fullE2E() {
        initializeSDK()
        let listener = MockLimeLinkListener()
        listener.onResultExpectation = expectation(description: "result")
        LimeLinkSDK.shared.addLinkListener(listener)

        MockURLProtocol.requestHandlers["api/v1/app/dynamic_link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.universalLinkResponseJSON)
        }
        MockURLProtocol.requestHandlers["stats/event"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.statsSuccessResponseJSON)
        }

        let url = URL(string: "https://limelink.org/universal-link/app/dynamic_link/campaign123")!
        LimeLinkSDK.shared.handleUniversalLink(url)

        wait(for: [listener.onResultExpectation!], timeout: 5.0)

        guard let result = listener.receivedResults.first else {
            XCTFail("Expected a result but got none")
            return
        }
        XCTAssertEqual(result.resolvedUri, TestConstants.universalLinkResponseURI)
        XCTAssertFalse(result.isDeferred)
    }

    // MARK: - Legacy E2E

    func test_legacyFlow_fullE2E() {
        initializeSDK()
        let listener = MockLimeLinkListener()
        listener.onResultExpectation = expectation(description: "result")
        LimeLinkSDK.shared.addLinkListener(listener)

        MockURLProtocol.requestHandlers["deep.limelink.org/link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.deeplinkResponseJSON)
        }
        MockURLProtocol.requestHandlers["stats/event"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.statsSuccessResponseJSON)
        }

        let url = URL(string: "https://custom.example.com/somepath")!
        LimeLinkSDK.shared.handleUniversalLink(url)

        wait(for: [listener.onResultExpectation!], timeout: 5.0)

        guard let result = listener.receivedResults.first else {
            XCTFail("Expected a result but got none")
            return
        }
        XCTAssertEqual(result.resolvedUri, "myapp://deeplink/abc")
        XCTAssertFalse(result.isDeferred)
    }

    // MARK: - Failure

    func test_apiFailure_notifiesError() {
        initializeSDK()
        let listener = MockLimeLinkListener()
        listener.onErrorExpectation = expectation(description: "error")
        LimeLinkSDK.shared.addLinkListener(listener)

        // No handlers → 404 default → nil → error

        let url = URL(string: "https://limelink.org/universal-link/app/dynamic_link/campaign")!
        LimeLinkSDK.shared.handleUniversalLink(url)

        wait(for: [listener.onErrorExpectation!], timeout: 5.0)
        XCTAssertEqual(listener.receivedErrors.count, 1)
    }

    // MARK: - Multiple Listeners

    func test_multipleListeners_allNotified() {
        initializeSDK()
        let listener1 = MockLimeLinkListener()
        let listener2 = MockLimeLinkListener()
        listener1.onResultExpectation = expectation(description: "result1")
        listener2.onResultExpectation = expectation(description: "result2")
        LimeLinkSDK.shared.addLinkListener(listener1)
        LimeLinkSDK.shared.addLinkListener(listener2)

        MockURLProtocol.requestHandlers["api/v1/app/dynamic_link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.universalLinkResponseJSON)
        }
        MockURLProtocol.requestHandlers["stats/event"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.statsSuccessResponseJSON)
        }

        let url = URL(string: "https://limelink.org/universal-link/app/dynamic_link/test")!
        LimeLinkSDK.shared.handleUniversalLink(url)

        wait(for: [listener1.onResultExpectation!, listener2.onResultExpectation!], timeout: 5.0)
        XCTAssertEqual(listener1.receivedResults.count, 1)
        XCTAssertEqual(listener2.receivedResults.count, 1)
    }

    // MARK: - Not Initialized

    func test_notInitialized_errorReturned() {
        // Don't initialize
        let listener = MockLimeLinkListener()
        listener.onErrorExpectation = expectation(description: "error")
        LimeLinkSDK.shared.addLinkListener(listener)

        let url = URL(string: "https://limelink.org/universal-link/app/dynamic_link/test")!
        LimeLinkSDK.shared.handleUniversalLink(url)

        wait(for: [listener.onErrorExpectation!], timeout: 5.0)
        XCTAssertEqual(listener.receivedErrors[0].code, -1)
        XCTAssertTrue(listener.receivedErrors[0].message.contains("not initialized"))
    }
}
