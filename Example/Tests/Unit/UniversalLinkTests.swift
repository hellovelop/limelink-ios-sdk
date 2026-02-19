import XCTest
@testable import LimelinkIOSSDK

class UniversalLinkTests: LimeLinkTestCase {

    override func setUp() {
        super.setUp()
        initializeSDK()
    }

    // MARK: - Subdomain Pattern

    func test_subdomainPattern_success() {
        let exp = expectation(description: "completion")

        MockURLProtocol.requestHandlers["://abc.limelink.org"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!, headers: ["X-Request-ID": "test-123"]), nil)
        }
        MockURLProtocol.requestHandlers["api/v1/app/dynamic_link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.universalLinkResponseJSON)
        }

        let url = URL(string: "https://abc.limelink.org/link/campaign123")!
        UniversalLink.shared.handleUniversalLink(url) { uri in
            XCTAssertEqual(uri, TestConstants.universalLinkResponseURI)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    func test_subdomainPattern_headFailure_fallsThroughToDirect() {
        let exp = expectation(description: "completion")

        MockURLProtocol.requestHandlers["://abc.limelink.org"] = { request in
            throw NSError(domain: "test", code: -1, userInfo: nil)
        }
        MockURLProtocol.requestHandlers["api/v1/app/dynamic_link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.universalLinkResponseJSON)
        }

        let url = URL(string: "https://abc.limelink.org/link/campaign123")!
        UniversalLink.shared.handleUniversalLink(url) { uri in
            // HEAD fails, so completion should still be called (either with result or nil)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    func test_subdomainPattern_apiFailure() {
        let exp = expectation(description: "completion")

        MockURLProtocol.requestHandlers["://abc.limelink.org"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), nil)
        }
        MockURLProtocol.requestHandlers["api/v1/app/dynamic_link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!, statusCode: 500), nil)
        }

        let url = URL(string: "https://abc.limelink.org/link/campaign123")!
        UniversalLink.shared.handleUniversalLink(url) { uri in
            XCTAssertNil(uri)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    func test_subdomainPattern_noLinkPath_fallsToDirectSuffix() {
        let exp = expectation(description: "completion")

        MockURLProtocol.requestHandlers["api/v1/app/dynamic_link"] = { request in
            XCTAssertTrue(request.url!.absoluteString.contains("dynamic_link/abc"))
            return (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.universalLinkResponseJSON)
        }

        let url = URL(string: "https://abc.limelink.org/other/path")!
        UniversalLink.shared.handleUniversalLink(url) { uri in
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    func test_subdomainPattern_passesHeaders() {
        let exp = expectation(description: "completion")

        MockURLProtocol.requestHandlers["://abc.limelink.org"] = { request in
            let headers = ["X-Request-ID": "req-456", "X-Forwarded-For": "1.2.3.4"]
            return (TestConstants.makeHTTPResponse(url: request.url!, headers: headers), nil)
        }
        MockURLProtocol.requestHandlers["api/v1/app/dynamic_link"] = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Request-ID"), "req-456")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Forwarded-For"), "1.2.3.4")
            return (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.universalLinkResponseJSON)
        }

        let url = URL(string: "https://abc.limelink.org/link/campaign123")!
        UniversalLink.shared.handleUniversalLink(url) { _ in
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    // MARK: - Direct Pattern

    func test_directPattern_universalLink() {
        let exp = expectation(description: "completion")

        MockURLProtocol.requestHandlers["api/v1/app/dynamic_link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.universalLinkResponseJSON)
        }

        let url = URL(string: "https://limelink.org/universal-link/app/dynamic_link/suffix123")!
        UniversalLink.shared.handleUniversalLink(url) { uri in
            XCTAssertEqual(uri, TestConstants.universalLinkResponseURI)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    func test_directPattern_apiV1() {
        let exp = expectation(description: "completion")

        MockURLProtocol.requestHandlers["api/v1/app/dynamic_link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.universalLinkResponseJSON)
        }

        let url = URL(string: "https://limelink.org/api/v1/app/dynamic_link/suffix123")!
        UniversalLink.shared.handleUniversalLink(url) { uri in
            XCTAssertEqual(uri, TestConstants.universalLinkResponseURI)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    func test_directPattern_noSuffix() {
        let exp = expectation(description: "completion")

        let url = URL(string: "https://limelink.org/other/path")!
        UniversalLink.shared.handleUniversalLink(url) { uri in
            XCTAssertNil(uri)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    func test_directPattern_wwwHost() {
        let exp = expectation(description: "completion")

        MockURLProtocol.requestHandlers["api/v1/app/dynamic_link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.universalLinkResponseJSON)
        }

        let url = URL(string: "https://www.limelink.org/universal-link/app/dynamic_link/suffix123")!
        UniversalLink.shared.handleUniversalLink(url) { uri in
            XCTAssertEqual(uri, TestConstants.universalLinkResponseURI)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    // MARK: - Legacy Pattern

    func test_legacyPattern_success() {
        let exp = expectation(description: "completion")

        MockURLProtocol.requestHandlers["deep.limelink.org/link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.deeplinkResponseJSON)
        }

        let url = URL(string: "https://custom.example.com/somepath")!
        UniversalLink.shared.handleUniversalLink(url) { uri in
            XCTAssertEqual(uri, "myapp://deeplink/abc")
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    func test_legacyPattern_failure() {
        let exp = expectation(description: "completion")

        MockURLProtocol.requestHandlers["deep.limelink.org/link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!, statusCode: 500), nil)
        }

        let url = URL(string: "https://custom.example.com/somepath")!
        UniversalLink.shared.handleUniversalLink(url) { uri in
            XCTAssertNil(uri)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    func test_legacyPattern_decodesResponse() {
        let exp = expectation(description: "completion")

        let jsonData = try! JSONEncoder().encode(["deeplinkUrl": "myapp://custom/path"])
        MockURLProtocol.requestHandlers["deep.limelink.org/link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), jsonData)
        }

        let url = URL(string: "https://other.domain.com/path")!
        UniversalLink.shared.handleUniversalLink(url) { uri in
            XCTAssertEqual(uri, "myapp://custom/path")
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    // MARK: - General

    func test_nilHost() {
        let exp = expectation(description: "completion")

        // URL with no host
        let url = URL(string: "file:///path/to/file")!
        UniversalLink.shared.handleUniversalLink(url) { uri in
            XCTAssertNil(uri)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    func test_usesConfigBaseUrl() {
        LimeLinkSDK.shared.resetForTesting()
        initializeSDK(baseUrl: "https://custom-api.example.com/")

        let exp = expectation(description: "completion")

        MockURLProtocol.requestHandlers["custom-api.example.com"] = { request in
            XCTAssertTrue(request.url!.absoluteString.contains("custom-api.example.com"))
            return (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.universalLinkResponseJSON)
        }

        let url = URL(string: "https://limelink.org/universal-link/app/dynamic_link/suffix")!
        UniversalLink.shared.handleUniversalLink(url) { uri in
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    func test_classMethodDelegates() {
        let exp = expectation(description: "completion")

        MockURLProtocol.requestHandlers["api/v1/app/dynamic_link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.universalLinkResponseJSON)
        }

        let url = URL(string: "https://limelink.org/universal-link/app/dynamic_link/suffix")!
        UniversalLink.handleUniversalLink(url) { uri in
            XCTAssertEqual(uri, TestConstants.universalLinkResponseURI)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    func test_completionCalledOnMainThread() {
        let exp = expectation(description: "completion")

        MockURLProtocol.requestHandlers["api/v1/app/dynamic_link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.universalLinkResponseJSON)
        }

        let url = URL(string: "https://limelink.org/universal-link/app/dynamic_link/suffix")!
        UniversalLink.shared.handleUniversalLink(url) { uri in
            XCTAssertTrue(Thread.isMainThread)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }
}
