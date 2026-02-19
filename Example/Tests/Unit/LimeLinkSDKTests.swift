import XCTest
@testable import LimelinkIOSSDK

class LimeLinkSDKTests: LimeLinkTestCase {

    // MARK: - Initialization

    func test_initialize_setsConfig() {
        initializeSDK()
        XCTAssertNotNil(LimeLinkSDK.shared.config)
        XCTAssertEqual(LimeLinkSDK.shared.config?.apiKey, TestConstants.testApiKey)
    }

    func test_initialize_setsInitialized() {
        XCTAssertFalse(LimeLinkSDK.shared.isInitialized)
        initializeSDK()
        XCTAssertTrue(LimeLinkSDK.shared.isInitialized)
    }

    func test_initialize_duplicateIgnored() {
        initializeSDK(apiKey: "first-key")
        initializeSDK(apiKey: "second-key")
        XCTAssertEqual(LimeLinkSDK.shared.config?.apiKey, "first-key")
    }

    func test_initialize_withDeferredEnabled_firstLaunch() {
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
        XCTAssertTrue(listener.receivedResults[0].isDeferred)
    }

    func test_initialize_withDeferredEnabled_notFirstLaunch() {
        // Simulate not first launch
        UserDefaults.standard.set(false, forKey: "is_first_launch")

        MockURLProtocol.requestHandlers["deferred-deep-link"] = { _ in
            XCTFail("Should not call deferred API on non-first launch")
            return (TestConstants.makeHTTPResponse(url: URL(string: "https://test.com")!), nil)
        }

        initializeSDK(deferredDeeplinkEnabled: true)

        let exp = expectation(description: "wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let deferredRequests = MockURLProtocol.capturedRequests.filter {
                $0.url?.absoluteString.contains("deferred-deep-link") == true
            }
            XCTAssertEqual(deferredRequests.count, 0)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 3.0)
    }

    // MARK: - Listener Management

    func test_addListener_receivesResults() {
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

        LimeLinkSDK.shared.handleUniversalLink(URL(string: "https://limelink.org/universal-link/app/dynamic_link/test")!)

        wait(for: [listener.onResultExpectation!], timeout: 5.0)
        XCTAssertEqual(listener.receivedResults.count, 1)
    }

    func test_removeListener_noLongerReceives() {
        initializeSDK()
        let listener = MockLimeLinkListener()
        LimeLinkSDK.shared.addLinkListener(listener)
        LimeLinkSDK.shared.removeLinkListener(listener)

        MockURLProtocol.requestHandlers["dynamic_link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.universalLinkResponseJSON)
        }
        MockURLProtocol.requestHandlers["stats/event"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.statsSuccessResponseJSON)
        }

        LimeLinkSDK.shared.handleUniversalLink(URL(string: "https://limelink.org/universal-link/app/dynamic_link/test")!)

        let exp = expectation(description: "wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            XCTAssertEqual(listener.receivedResults.count, 0)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    func test_multipleListeners_allReceive() {
        initializeSDK()
        let listener1 = MockLimeLinkListener()
        let listener2 = MockLimeLinkListener()
        listener1.onResultExpectation = expectation(description: "result1")
        listener2.onResultExpectation = expectation(description: "result2")
        LimeLinkSDK.shared.addLinkListener(listener1)
        LimeLinkSDK.shared.addLinkListener(listener2)

        MockURLProtocol.requestHandlers["dynamic_link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.universalLinkResponseJSON)
        }
        MockURLProtocol.requestHandlers["stats/event"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.statsSuccessResponseJSON)
        }

        LimeLinkSDK.shared.handleUniversalLink(URL(string: "https://limelink.org/universal-link/app/dynamic_link/test")!)

        wait(for: [listener1.onResultExpectation!, listener2.onResultExpectation!], timeout: 5.0)
        XCTAssertEqual(listener1.receivedResults.count, 1)
        XCTAssertEqual(listener2.receivedResults.count, 1)
    }

    func test_listenerWeakReference() {
        initializeSDK()
        var listener: MockLimeLinkListener? = MockLimeLinkListener()
        weak var weakRef = listener
        LimeLinkSDK.shared.addLinkListener(listener!)

        listener = nil

        // Listener should be deallocated since NSHashTable uses weak references
        XCTAssertNil(weakRef)
    }

    // MARK: - handleUniversalLink

    func test_handleUniversalLink_success_notifiesListener() {
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

        let url = URL(string: "https://limelink.org/universal-link/app/dynamic_link/campaign")!
        LimeLinkSDK.shared.handleUniversalLink(url)

        wait(for: [listener.onResultExpectation!], timeout: 5.0)
        XCTAssertEqual(listener.receivedResults[0].resolvedUri, TestConstants.universalLinkResponseURI)
    }

    func test_handleUniversalLink_failure_notifiesError() {
        initializeSDK()
        let listener = MockLimeLinkListener()
        listener.onErrorExpectation = expectation(description: "error")
        LimeLinkSDK.shared.addLinkListener(listener)

        // No mock handlers set → 404 default → nil URI → error

        let url = URL(string: "https://limelink.org/universal-link/app/dynamic_link/campaign")!
        LimeLinkSDK.shared.handleUniversalLink(url)

        wait(for: [listener.onErrorExpectation!], timeout: 5.0)
        XCTAssertEqual(listener.receivedErrors.count, 1)
        XCTAssertEqual(listener.receivedErrors[0].code, 404)
    }

    func test_handleUniversalLink_notInitialized_notifiesError() {
        // Don't initialize SDK
        let listener = MockLimeLinkListener()
        listener.onErrorExpectation = expectation(description: "error")
        LimeLinkSDK.shared.addLinkListener(listener)

        let url = URL(string: "https://limelink.org/universal-link/app/dynamic_link/campaign")!
        LimeLinkSDK.shared.handleUniversalLink(url)

        wait(for: [listener.onErrorExpectation!], timeout: 5.0)
        XCTAssertEqual(listener.receivedErrors[0].code, -1)
    }

    func test_handleUniversalLink_setsIsDeferredFalse() {
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

        LimeLinkSDK.shared.handleUniversalLink(URL(string: "https://limelink.org/universal-link/app/dynamic_link/test")!)

        wait(for: [listener.onResultExpectation!], timeout: 5.0)
        XCTAssertFalse(listener.receivedResults[0].isDeferred)
    }

    func test_handleUniversalLink_tracksStats() {
        initializeSDK()
        let listener = MockLimeLinkListener()
        listener.onResultExpectation = expectation(description: "result")
        LimeLinkSDK.shared.addLinkListener(listener)

        var statsReceived = false
        MockURLProtocol.requestHandlers["dynamic_link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.universalLinkResponseJSON)
        }
        MockURLProtocol.requestHandlers["stats/event"] = { request in
            statsReceived = true
            return (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.statsSuccessResponseJSON)
        }

        LimeLinkSDK.shared.handleUniversalLink(URL(string: "https://limelink.org/universal-link/app/dynamic_link/campaign")!)

        wait(for: [listener.onResultExpectation!], timeout: 5.0)

        // Wait a bit more for stats to be sent asynchronously
        let statsExp = expectation(description: "stats")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            XCTAssertTrue(statsReceived)
            statsExp.fulfill()
        }

        wait(for: [statsExp], timeout: 3.0)
    }

    // MARK: - handleDeferredDeepLink

    func test_handleDeferredDeepLink_success() {
        initializeSDK()
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
            XCTAssertEqual(result?.resolvedUri, "myapp://deferred/456")
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    func test_handleDeferredDeepLink_failure() {
        initializeSDK()
        let exp = expectation(description: "deferred")

        MockURLProtocol.requestHandlers["deferred-deep-link"] = { _ in
            throw NSError(domain: "test", code: -1, userInfo: nil)
        }

        LimeLinkSDK.shared.handleDeferredDeepLink { result, error in
            XCTAssertNil(result)
            XCTAssertNotNil(error)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    func test_handleDeferredDeepLink_notInitialized() {
        // Don't initialize SDK
        let exp = expectation(description: "deferred")

        LimeLinkSDK.shared.handleDeferredDeepLink { result, error in
            XCTAssertNil(result)
            XCTAssertNotNil(error)
            XCTAssertEqual(error?.code, -1)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    func test_handleDeferredDeepLink_populatesOriginalUrl() {
        initializeSDK()
        let exp = expectation(description: "deferred detail")

        MockURLProtocol.requestHandlers["deferred-deep-link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.suffixResponseJSON)
        }
        MockURLProtocol.requestHandlers["dynamic_link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.dynamicLinkResponseJSON)
        }

        LimeLinkSDK.shared.handleDeferredDeepLink { result, error in
            XCTAssertEqual(result?.originalUrl, "https://abc.limelink.org/link/campaign123")
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    func test_handleDeferredDeepLink_parsesQueryParams() {
        initializeSDK()
        let exp = expectation(description: "deferred query params")

        MockURLProtocol.requestHandlers["deferred-deep-link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.suffixResponseWithQueryParamsJSON)
        }
        MockURLProtocol.requestHandlers["dynamic_link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.dynamicLinkResponseJSON)
        }

        LimeLinkSDK.shared.handleDeferredDeepLink { result, error in
            XCTAssertNotNil(result)
            XCTAssertEqual(result?.queryParams["utm_source"], "google")
            XCTAssertEqual(result?.queryParams["product_id"], "789")
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    func test_handleDeferredDeepLink_noQueryParams_emptyDict() {
        initializeSDK()
        let exp = expectation(description: "deferred no params")

        MockURLProtocol.requestHandlers["deferred-deep-link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.suffixResponseJSON)
        }
        MockURLProtocol.requestHandlers["dynamic_link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.dynamicLinkResponseJSON)
        }

        LimeLinkSDK.shared.handleDeferredDeepLink { result, error in
            XCTAssertNotNil(result)
            XCTAssertTrue(result?.queryParams.isEmpty == true)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    func test_handleDeferredDeepLink_resultIsDeferred() {
        initializeSDK()
        let exp = expectation(description: "deferred")

        MockURLProtocol.requestHandlers["deferred-deep-link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.suffixResponseJSON)
        }
        MockURLProtocol.requestHandlers["dynamic_link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.dynamicLinkResponseJSON)
        }

        LimeLinkSDK.shared.handleDeferredDeepLink { result, error in
            XCTAssertTrue(result?.isDeferred == true)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    // MARK: - trackLinkStatus

    func test_trackLinkStatus_sendsStats() {
        initializeSDK()
        let exp = expectation(description: "stats")

        MockURLProtocol.requestHandlers["stats/event"] = { request in
            exp.fulfill()
            return (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.statsSuccessResponseJSON)
        }

        LimeLinkSDK.shared.trackLinkStatus(url: URL(string: "https://example.com/campaign/sub/detail")!)

        wait(for: [exp], timeout: 5.0)
    }

    func test_trackLinkStatus_notInitialized_doesNothing() {
        // Don't initialize SDK
        MockURLProtocol.requestHandlers["stats/event"] = { _ in
            XCTFail("Should not send stats when not initialized")
            return (TestConstants.makeHTTPResponse(url: URL(string: "https://test.com")!), nil)
        }

        LimeLinkSDK.shared.trackLinkStatus(url: URL(string: "https://example.com/campaign")!)

        let exp = expectation(description: "wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            exp.fulfill()
        }

        wait(for: [exp], timeout: 3.0)
    }
}
