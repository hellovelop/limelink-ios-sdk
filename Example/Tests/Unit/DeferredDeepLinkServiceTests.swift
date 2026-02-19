import XCTest
@testable import LimelinkIOSSDK

class DeferredDeepLinkServiceTests: LimeLinkTestCase {

    // MARK: - Success

    func test_getDeferredDeepLink_success() {
        let exp = expectation(description: "deferred")

        MockURLProtocol.requestHandlers["deferred-deep-link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.suffixResponseJSON)
        }
        MockURLProtocol.requestHandlers["dynamic_link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.dynamicLinkResponseJSON)
        }

        DeferredDeepLinkService.getDeferredDeepLink(baseUrl: TestConstants.testBaseUrl) { result in
            switch result {
            case .success(let uri):
                XCTAssertEqual(uri, "myapp://deferred/456")
            case .failure(let error):
                XCTFail("Expected success, got \(error)")
            }
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    // MARK: - Suffix Failures

    func test_getDeferredDeepLink_suffixNotFound() {
        let exp = expectation(description: "deferred")

        MockURLProtocol.requestHandlers["deferred-deep-link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.suffixResponseNoMatchJSON)
        }

        DeferredDeepLinkService.getDeferredDeepLink(baseUrl: TestConstants.testBaseUrl) { result in
            switch result {
            case .success:
                XCTFail("Expected failure")
            case .failure(let error):
                XCTAssertEqual((error as NSError).code, 404)
            }
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    func test_getDeferredDeepLink_suffixApiError() {
        let exp = expectation(description: "deferred")

        MockURLProtocol.requestHandlers["deferred-deep-link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!, statusCode: 500), "error".data(using: .utf8)!)
        }

        DeferredDeepLinkService.getDeferredDeepLink(baseUrl: TestConstants.testBaseUrl) { result in
            switch result {
            case .success:
                XCTFail("Expected failure")
            case .failure(let error):
                XCTAssertEqual((error as NSError).code, 500)
            }
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    // MARK: - Dynamic Link Failures

    func test_getDeferredDeepLink_dynamicLinkError() {
        let exp = expectation(description: "deferred")

        MockURLProtocol.requestHandlers["deferred-deep-link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.suffixResponseJSON)
        }
        MockURLProtocol.requestHandlers["dynamic_link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!, statusCode: 500), "error".data(using: .utf8)!)
        }

        DeferredDeepLinkService.getDeferredDeepLink(baseUrl: TestConstants.testBaseUrl) { result in
            switch result {
            case .success:
                XCTFail("Expected failure")
            case .failure:
                break
            }
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    // MARK: - Base URL

    func test_getDeferredDeepLink_usesBaseUrl() {
        let exp = expectation(description: "deferred")

        MockURLProtocol.requestHandlers["custom.example.com"] = { request in
            XCTAssertTrue(request.url!.absoluteString.contains("custom.example.com"))
            return (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.suffixResponseJSON)
        }
        MockURLProtocol.requestHandlers["dynamic_link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.dynamicLinkResponseJSON)
        }

        DeferredDeepLinkService.getDeferredDeepLink(baseUrl: "https://custom.example.com/") { _ in
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    func test_getDeferredDeepLink_defaultBaseUrl() {
        let exp = expectation(description: "deferred")

        MockURLProtocol.requestHandlers["limelink.org/api/v1/deferred"] = { request in
            XCTAssertTrue(request.url!.absoluteString.contains("limelink.org"))
            return (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.suffixResponseJSON)
        }
        MockURLProtocol.requestHandlers["dynamic_link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.dynamicLinkResponseJSON)
        }

        DeferredDeepLinkService.getDeferredDeepLink { _ in
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    // MARK: - Request Verification

    func test_getDeferredDeepLink_includesDeviceParams() {
        let exp = expectation(description: "deferred")

        MockURLProtocol.requestHandlers["deferred-deep-link"] = { request in
            let urlString = request.url!.absoluteString
            XCTAssertTrue(urlString.contains("width="))
            XCTAssertTrue(urlString.contains("height="))
            XCTAssertTrue(urlString.contains("user_agent="))
            return (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.suffixResponseJSON)
        }
        MockURLProtocol.requestHandlers["dynamic_link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.dynamicLinkResponseJSON)
        }

        DeferredDeepLinkService.getDeferredDeepLink(baseUrl: TestConstants.testBaseUrl) { _ in
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    func test_getDeferredDeepLink_includesEventTypeSetup() {
        let exp = expectation(description: "deferred")

        MockURLProtocol.requestHandlers["deferred-deep-link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.suffixResponseJSON)
        }
        MockURLProtocol.requestHandlers["dynamic_link"] = { request in
            XCTAssertTrue(request.url!.absoluteString.contains("event_type=setup"))
            return (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.dynamicLinkResponseJSON)
        }

        DeferredDeepLinkService.getDeferredDeepLink(baseUrl: TestConstants.testBaseUrl) { _ in
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    func test_getDeferredDeepLink_includesFullRequestUrl() {
        let exp = expectation(description: "deferred")

        MockURLProtocol.requestHandlers["deferred-deep-link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.suffixResponseJSON)
        }
        MockURLProtocol.requestHandlers["dynamic_link"] = { request in
            XCTAssertTrue(request.url!.absoluteString.contains("full_request_url="))
            return (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.dynamicLinkResponseJSON)
        }

        DeferredDeepLinkService.getDeferredDeepLink(baseUrl: TestConstants.testBaseUrl) { _ in
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    // MARK: - Detail (getDeferredDeepLinkWithDetail)

    func test_getDeferredDeepLinkWithDetail_returnsOriginalUrl() {
        let exp = expectation(description: "detail")

        MockURLProtocol.requestHandlers["deferred-deep-link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.suffixResponseJSON)
        }
        MockURLProtocol.requestHandlers["dynamic_link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.dynamicLinkResponseJSON)
        }

        DeferredDeepLinkService.getDeferredDeepLinkWithDetail(baseUrl: TestConstants.testBaseUrl) { result in
            switch result {
            case .success(let info):
                XCTAssertEqual(info.uri, "myapp://deferred/456")
                XCTAssertEqual(info.originalUrl, "https://abc.limelink.org/link/campaign123")
            case .failure(let error):
                XCTFail("Expected success, got \(error)")
            }
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    func test_getDeferredDeepLinkWithDetail_withQueryParams() {
        let exp = expectation(description: "detail with params")

        MockURLProtocol.requestHandlers["deferred-deep-link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.suffixResponseWithQueryParamsJSON)
        }
        MockURLProtocol.requestHandlers["dynamic_link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.dynamicLinkResponseJSON)
        }

        DeferredDeepLinkService.getDeferredDeepLinkWithDetail(baseUrl: TestConstants.testBaseUrl) { result in
            switch result {
            case .success(let info):
                XCTAssertEqual(info.uri, "myapp://deferred/456")
                XCTAssertTrue(info.originalUrl?.contains("utm_source=google") == true)
                XCTAssertTrue(info.originalUrl?.contains("product_id=789") == true)
            case .failure(let error):
                XCTFail("Expected success, got \(error)")
            }
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    func test_getDeferredDeepLinkWithDetail_failure_noOriginalUrl() {
        let exp = expectation(description: "detail failure")

        MockURLProtocol.requestHandlers["deferred-deep-link"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.suffixResponseNoMatchJSON)
        }

        DeferredDeepLinkService.getDeferredDeepLinkWithDetail(baseUrl: TestConstants.testBaseUrl) { result in
            switch result {
            case .success:
                XCTFail("Expected failure")
            case .failure:
                break
            }
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    // MARK: - Network Error

    func test_getDeferredDeepLink_networkError() {
        let exp = expectation(description: "deferred")

        MockURLProtocol.requestHandlers["deferred-deep-link"] = { _ in
            throw NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
        }

        DeferredDeepLinkService.getDeferredDeepLink(baseUrl: TestConstants.testBaseUrl) { result in
            switch result {
            case .success:
                XCTFail("Expected failure")
            case .failure(let error):
                XCTAssertEqual((error as NSError).code, NSURLErrorNotConnectedToInternet)
            }
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }
}
