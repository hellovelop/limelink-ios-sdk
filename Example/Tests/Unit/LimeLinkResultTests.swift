import XCTest
@testable import LimelinkIOSSDK

class LimeLinkResultTests: XCTestCase {

    func test_properties() {
        let pathParams = PathParamResponse(mainPath: "main", subPath: "sub")
        let result = LimeLinkResult(
            originalUrl: "https://example.com",
            resolvedUri: "myapp://page",
            queryParams: ["k": "v"],
            pathParams: pathParams,
            isDeferred: true
        )
        XCTAssertEqual(result.originalUrl, "https://example.com")
        XCTAssertEqual(result.resolvedUri, "myapp://page")
        XCTAssertEqual(result.queryParams["k"], "v")
        XCTAssertEqual(result.pathParams.mainPath, "main")
        XCTAssertTrue(result.isDeferred)
    }

    func test_defaultValues() {
        let result = LimeLinkResult()
        XCTAssertNil(result.originalUrl)
        XCTAssertNil(result.resolvedUri)
        XCTAssertTrue(result.queryParams.isEmpty)
        XCTAssertEqual(result.pathParams.mainPath, "")
        XCTAssertFalse(result.isDeferred)
    }

    func test_isDeferred() {
        let deferred = LimeLinkResult(isDeferred: true)
        XCTAssertTrue(deferred.isDeferred)

        let notDeferred = LimeLinkResult(isDeferred: false)
        XCTAssertFalse(notDeferred.isDeferred)
    }

    func test_queryParams() {
        let result = LimeLinkResult(queryParams: ["a": "1", "b": "2", "c": "3"])
        XCTAssertEqual(result.queryParams.count, 3)
        XCTAssertEqual(result.queryParams["a"], "1")
        XCTAssertEqual(result.queryParams["b"], "2")
        XCTAssertEqual(result.queryParams["c"], "3")
    }
}
