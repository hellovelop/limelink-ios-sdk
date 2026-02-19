import XCTest
@testable import LimelinkIOSSDK

class LinkStatsTests: LimeLinkTestCase {

    func test_isFirstLaunch_firstCall_returnsTrue() {
        XCTAssertTrue(LinkStats.isFirstLaunch())
    }

    func test_isFirstLaunch_secondCall_returnsFalse() {
        _ = LinkStats.isFirstLaunch()
        XCTAssertFalse(LinkStats.isFirstLaunch())
    }

    func test_isFirstLaunch_consumesBehavior() {
        XCTAssertTrue(LinkStats.isFirstLaunch())
        XCTAssertFalse(LinkStats.isFirstLaunch())
        XCTAssertFalse(LinkStats.isFirstLaunch())
    }

    func test_isFirstLaunch_afterReset_returnsTrue() {
        _ = LinkStats.isFirstLaunch()
        XCTAssertFalse(LinkStats.isFirstLaunch())

        UserDefaults.standard.removeObject(forKey: "is_first_launch")

        XCTAssertTrue(LinkStats.isFirstLaunch())
    }
}
