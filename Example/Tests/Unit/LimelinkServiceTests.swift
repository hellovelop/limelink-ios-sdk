import XCTest
@testable import LimelinkIOSSDK

class LimelinkServiceTests: LimeLinkTestCase {

    override func setUp() {
        super.setUp()
        initializeSDK()
    }

    // MARK: - sendLimeLink

    func test_sendLimeLink_success() {
        let exp = expectation(description: "send")

        MockURLProtocol.requestHandlers["stats/event"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.statsSuccessResponseJSON)
        }

        let request = LimeLinkRequest(private_key: "key", suffix: "sfx", event_type: "rerun")
        sendLimeLink(data: request) { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                XCTFail("Expected success, got \(error)")
            }
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    func test_sendLimeLink_failure() {
        let exp = expectation(description: "send")

        MockURLProtocol.requestHandlers["stats/event"] = { request in
            (TestConstants.makeHTTPResponse(url: request.url!, statusCode: 500), nil)
        }

        let request = LimeLinkRequest(private_key: "key", suffix: "sfx", event_type: "rerun")
        sendLimeLink(data: request) { result in
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

    func test_sendLimeLink_networkError() {
        let exp = expectation(description: "send")

        MockURLProtocol.requestHandlers["stats/event"] = { _ in
            throw NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil)
        }

        let request = LimeLinkRequest(private_key: "key", suffix: "sfx", event_type: "rerun")
        sendLimeLink(data: request) { result in
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

    func test_sendLimeLink_sendsJSON() {
        let exp = expectation(description: "send")

        MockURLProtocol.requestHandlers["stats/event"] = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            // URLProtocol converts httpBody to httpBodyStream, so use helper
            let bodyData = MockURLProtocol.bodyData(from: request)
            XCTAssertNotNil(bodyData)

            if let body = bodyData {
                let decoded = try JSONDecoder().decode(LimeLinkRequest.self, from: body)
                XCTAssertEqual(decoded.private_key, "test-key")
                XCTAssertEqual(decoded.suffix, "test-suffix")
            }

            return (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.statsSuccessResponseJSON)
        }

        let request = LimeLinkRequest(private_key: "test-key", suffix: "test-suffix", event_type: "rerun")
        sendLimeLink(data: request) { _ in
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    func test_sendLimeLink_correctUrl() {
        let exp = expectation(description: "send")

        MockURLProtocol.requestHandlers["stats/event"] = { request in
            XCTAssertTrue(request.url!.absoluteString.contains("test.limelink.org/api/v1/stats/event"))
            return (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.statsSuccessResponseJSON)
        }

        let request = LimeLinkRequest(private_key: "key", suffix: "sfx", event_type: "rerun")
        sendLimeLink(data: request) { _ in
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    // MARK: - saveLimeLinkStatusInternal

    func test_saveLimeLinkStatusInternal_sendsPost() {
        let exp = expectation(description: "stats")

        MockURLProtocol.requestHandlers["stats/event"] = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            exp.fulfill()
            return (TestConstants.makeHTTPResponse(url: request.url!), TestConstants.statsSuccessResponseJSON)
        }

        let url = URL(string: "https://example.com/campaign/sub/detail")!
        saveLimeLinkStatusInternal(url: url, privateKey: TestConstants.testApiKey)

        wait(for: [exp], timeout: 5.0)
    }

    func test_saveLimeLinkStatusInternal_emptyMainPath_doesNothing() {
        MockURLProtocol.requestHandlers["stats/event"] = { request in
            XCTFail("Should not send request for empty mainPath")
            return (TestConstants.makeHTTPResponse(url: request.url!), nil)
        }

        let url = URL(string: "https://example.com")!
        saveLimeLinkStatusInternal(url: url, privateKey: TestConstants.testApiKey)

        // Give time to confirm no request is sent
        let exp = expectation(description: "wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let statsRequests = MockURLProtocol.capturedRequests.filter {
                $0.url?.absoluteString.contains("stats/event") == true
            }
            XCTAssertEqual(statsRequests.count, 0)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 3.0)
    }

    // MARK: - createLimeLinkRequest

    func test_createLimeLinkRequest_correctFields() {
        let pathParam = PathParamResponse(mainPath: "main", subPath: "sub")
        let request = createLimeLinkRequest(privateKey: "pk", pathParamResponse: pathParam, eventType: .FIRST_RUN)
        XCTAssertEqual(request.private_key, "pk")
        XCTAssertEqual(request.suffix, "main")
        XCTAssertEqual(request.handle, "sub")
        XCTAssertEqual(request.event_type, "first_run")
        XCTAssertEqual(request.operating_system, "ios")
    }
}
