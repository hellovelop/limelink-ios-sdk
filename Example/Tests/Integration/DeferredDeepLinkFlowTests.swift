import XCTest
@testable import LimelinkIOSSDK

class DeferredDeepLinkFlowTests: LimeLinkTestCase {

    // MARK: - Auto Deferred on First Launch

    func test_autoDeferred_firstLaunch() {
        let listener = MockLimeLinkListener()
        listener.onResultExpectation = expectation(description: "deferred result")
        LimeLinkSDK.shared.addLinkListener(listener)

        MockURLProtocol.requestHandlers["deferred-deep-link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.suffixResponseJSON)
        }
        MockURLProtocol.requestHandlers["dynamic_link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.dynamicLinkResponseJSON)
        }

        // First launch + deferred enabled → auto check
        initializeSDK(deferredDeeplinkEnabled: true)

        wait(for: [listener.onResultExpectation!], timeout: 5.0)

        XCTAssertEqual(listener.receivedResults.count, 1)
        let result = listener.receivedResults[0]
        XCTAssertTrue(result.isDeferred)
        XCTAssertEqual(result.resolvedUri, "myapp://deferred/456")
        XCTAssertEqual(result.originalUrl, "https://abc.limelink.org/link/campaign123")
    }

    // MARK: - Manual Deferred

    func test_manualDeferred_success() {
        initializeSDK(deferredDeeplinkEnabled: false)
        let exp = expectation(description: "deferred")

        MockURLProtocol.requestHandlers["deferred-deep-link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.suffixResponseJSON)
        }
        MockURLProtocol.requestHandlers["dynamic_link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.dynamicLinkResponseJSON)
        }

        LimeLinkSDK.shared.handleDeferredDeepLink { result, error in
            XCTAssertNotNil(result)
            XCTAssertNil(error)
            XCTAssertTrue(result!.isDeferred)
            XCTAssertEqual(result!.resolvedUri, "myapp://deferred/456")
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    // MARK: - No Suffix Match

    func test_autoDeferred_noSuffix_errorsOut() {
        let listener = MockLimeLinkListener()
        listener.onErrorExpectation = expectation(description: "error")
        LimeLinkSDK.shared.addLinkListener(listener)

        MockURLProtocol.requestHandlers["deferred-deep-link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.suffixResponseNoMatchJSON)
        }

        initializeSDK(deferredDeeplinkEnabled: true)

        wait(for: [listener.onErrorExpectation!], timeout: 5.0)
        XCTAssertEqual(listener.receivedErrors.count, 1)
    }

    // MARK: - Second Launch Skipped

    func test_autoDeferred_secondLaunch_skipped() {
        // Simulate not first launch
        UserDefaults.standard.set(false, forKey: "is_first_launch")

        MockURLProtocol.requestHandlers["deferred-deep-link"] = { _ in
            XCTFail("Should not call deferred API on second launch")
            return (TestConstants.makeHTTPResponse(url: URL(string: "https://test.com")!), nil)
        }

        initializeSDK(deferredDeeplinkEnabled: true)

        let exp = expectation(description: "wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let deferredRequests = MockURLProtocol.capturedRequests.filter {
                $0.url?.absoluteString.contains("deferred-deep-link") == true
            }
            XCTAssertEqual(deferredRequests.count, 0)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 3.0)
    }

    // MARK: - Detail Info with Query Params

    func test_autoDeferred_firstLaunch_withQueryParams() {
        let listener = MockLimeLinkListener()
        listener.onResultExpectation = expectation(description: "deferred with params")
        LimeLinkSDK.shared.addLinkListener(listener)

        MockURLProtocol.requestHandlers["deferred-deep-link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.suffixResponseWithQueryParamsJSON)
        }
        MockURLProtocol.requestHandlers["dynamic_link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.dynamicLinkResponseJSON)
        }

        initializeSDK(deferredDeeplinkEnabled: true)

        wait(for: [listener.onResultExpectation!], timeout: 5.0)

        let result = listener.receivedResults[0]
        XCTAssertTrue(result.isDeferred)
        XCTAssertEqual(result.resolvedUri, "myapp://deferred/456")
        XCTAssertEqual(result.originalUrl, "https://abc.limelink.org/link/campaign123?utm_source=google&product_id=789")
        XCTAssertEqual(result.queryParams["utm_source"], "google")
        XCTAssertEqual(result.queryParams["product_id"], "789")
    }

    // MARK: - Sequential: Deferred then Universal

    func test_deferredThenUniversal_sequential() {
        let listener = MockLimeLinkListener()
        listener.onResultExpectation = expectation(description: "deferred result")
        LimeLinkSDK.shared.addLinkListener(listener)

        MockURLProtocol.requestHandlers["deferred-deep-link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.suffixResponseJSON)
        }
        MockURLProtocol.requestHandlers["dynamic_link"] = { request in
            // Return different URI based on whether it's deferred (has event_type) or universal
            if request.url!.absoluteString.contains("event_type=setup") {
                return (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.dynamicLinkResponseJSON)
            } else {
                return (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.universalLinkResponseJSON)
            }
        }
        MockURLProtocol.requestHandlers["stats/event"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.statsSuccessResponseJSON)
        }

        // Step 1: Deferred deep link via auto-init
        initializeSDK(deferredDeeplinkEnabled: true)

        wait(for: [listener.onResultExpectation!], timeout: 5.0)
        XCTAssertEqual(listener.receivedResults.count, 1)
        XCTAssertTrue(listener.receivedResults[0].isDeferred)

        // Step 2: Universal link
        listener.onResultExpectation = expectation(description: "universal result")

        let url = URL(string: "https://limelink.org/universal-link/app/dynamic_link/campaign")!
        LimeLinkSDK.shared.handleUniversalLink(url)

        wait(for: [listener.onResultExpectation!], timeout: 5.0)
        XCTAssertEqual(listener.receivedResults.count, 2)
        XCTAssertTrue(listener.receivedResults[0].isDeferred)
        XCTAssertFalse(listener.receivedResults[1].isDeferred)
    }
}
