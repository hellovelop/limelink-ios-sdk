import XCTest
@testable import LimelinkIOSSDK

class EventTypeTests: XCTestCase {

    func test_firstRunRawValue() {
        XCTAssertEqual(EventType.FIRST_RUN.rawValue, "first_run")
    }

    func test_rerunRawValue() {
        XCTAssertEqual(EventType.RERUN.rawValue, "rerun")
    }

    func test_setupRawValue() {
        XCTAssertEqual(EventType.SETUP.rawValue, "setup")
    }
}
