import XCTest
@testable import LimelinkIOSSDK

class UrlHandlerTests: XCTestCase {

    // MARK: - parseQueryParams

    func test_parseQueryParams_withSchemeURL() {
        let url = URL(string: "myapp://open?original-url=https%3A%2F%2Fexample.com%2Fpage%3Fkey%3Dvalue")!
        let params = parseQueryParams(from: url)
        XCTAssertEqual(params["key"], "value")
    }

    func test_parseQueryParams_noOriginalUrl() {
        let url = URL(string: "myapp://open?other=param")!
        let params = parseQueryParams(from: url)
        XCTAssertTrue(params.isEmpty)
    }

    func test_parseQueryParams_nilURL() {
        let params = parseQueryParams(from: nil)
        XCTAssertTrue(params.isEmpty)
    }

    func test_parseQueryParams_multipleParams() {
        let url = URL(string: "myapp://open?original-url=https%3A%2F%2Fexample.com%2Fpage%3Fa%3D1%26b%3D2%26c%3D3")!
        let params = parseQueryParams(from: url)
        XCTAssertEqual(params["a"], "1")
        XCTAssertEqual(params["b"], "2")
        XCTAssertEqual(params["c"], "3")
    }

    // MARK: - parsePathParams

    func test_parsePathParams_normalPath() {
        let url = URL(string: "https://example.com/main/sub/detail")!
        let result = parsePathParams(from: url)
        XCTAssertEqual(result.mainPath, "main")
        XCTAssertEqual(result.subPath, "detail")
    }

    func test_parsePathParams_singleSegment() {
        let url = URL(string: "https://example.com/only")!
        let result = parsePathParams(from: url)
        XCTAssertEqual(result.mainPath, "only")
        XCTAssertNil(result.subPath)
    }

    func test_parsePathParams_noPath() {
        let url = URL(string: "https://example.com")!
        let result = parsePathParams(from: url)
        XCTAssertEqual(result.mainPath, "")
    }

    func test_parsePathParams_nilURL() {
        let result = parsePathParams(from: nil)
        XCTAssertEqual(result.mainPath, "")
        XCTAssertEqual(result.subPath, "")
    }

    func test_parsePathParams_twoSegments() {
        let url = URL(string: "https://example.com/first/second")!
        let result = parsePathParams(from: url)
        XCTAssertEqual(result.mainPath, "first")
        XCTAssertNil(result.subPath)
    }

    // MARK: - getScheme

    func test_getScheme_extractsOriginalUrl() {
        let url = URL(string: "myapp://open?original-url=https%3A%2F%2Fexample.com%2Fpage")!
        let scheme = UrlHandler.getScheme(from: url)
        XCTAssertEqual(scheme, "https://example.com/page")
    }

    func test_getScheme_noOriginalUrl() {
        let url = URL(string: "myapp://open?other=param")!
        let scheme = UrlHandler.getScheme(from: url)
        XCTAssertNil(scheme)
    }

    func test_getScheme_nilURL() {
        let scheme = UrlHandler.getScheme(from: nil)
        XCTAssertNil(scheme)
    }
}
