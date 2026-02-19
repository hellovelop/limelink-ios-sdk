import XCTest
@testable import LimelinkIOSSDK

class LimeLinkRequestTests: XCTestCase {

    func test_init_allProperties() {
        let request = LimeLinkRequest(private_key: "pk", suffix: "sfx", handle: "hdl", event_type: "rerun", operating_system: "android")
        XCTAssertEqual(request.private_key, "pk")
        XCTAssertEqual(request.suffix, "sfx")
        XCTAssertEqual(request.handle, "hdl")
        XCTAssertEqual(request.event_type, "rerun")
        XCTAssertEqual(request.operating_system, "android")
    }

    func test_defaultOperatingSystem() {
        let request = LimeLinkRequest(private_key: "pk", suffix: "sfx", event_type: "first_run")
        XCTAssertEqual(request.operating_system, "ios")
    }

    func test_codableEncoding() throws {
        let request = LimeLinkRequest(private_key: "pk", suffix: "sfx", handle: "hdl", event_type: "rerun")
        let data = try JSONEncoder().encode(request)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(dict["private_key"] as? String, "pk")
        XCTAssertEqual(dict["suffix"] as? String, "sfx")
        XCTAssertEqual(dict["handle"] as? String, "hdl")
        XCTAssertEqual(dict["event_type"] as? String, "rerun")
        XCTAssertEqual(dict["operating_system"] as? String, "ios")
    }

    func test_createLimeLinkRequest() {
        let pathParam = PathParamResponse(mainPath: "campaign", subPath: "detail")
        let request = createLimeLinkRequest(privateKey: "my-key", pathParamResponse: pathParam, eventType: .RERUN)
        XCTAssertEqual(request.private_key, "my-key")
        XCTAssertEqual(request.suffix, "campaign")
        XCTAssertEqual(request.handle, "detail")
        XCTAssertEqual(request.event_type, "rerun")
        XCTAssertEqual(request.operating_system, "ios")
    }
}
