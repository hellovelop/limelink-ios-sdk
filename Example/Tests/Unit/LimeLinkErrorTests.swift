import XCTest
@testable import LimelinkIOSSDK

class LimeLinkErrorTests: XCTestCase {

    func test_properties() {
        let error = LimeLinkError(code: 404, message: "Not found")
        XCTAssertEqual(error.code, 404)
        XCTAssertEqual(error.message, "Not found")
        XCTAssertNil(error.underlyingError)
    }

    func test_localizedError() {
        let error = LimeLinkError(code: 500, message: "Server error")
        XCTAssertEqual(error.errorDescription, "Server error")
    }

    func test_description() {
        let error = LimeLinkError(code: 42, message: "Custom")
        XCTAssertEqual(error.description, "LimeLinkError(code: 42, message: Custom)")
    }

    func test_underlyingError() {
        let underlying = NSError(domain: "test", code: 1, userInfo: nil)
        let error = LimeLinkError(code: 500, message: "Wrapped", underlyingError: underlying)
        XCTAssertNotNil(error.underlyingError)
        XCTAssertEqual((error.underlyingError as NSError?)?.domain, "test")
    }
}
