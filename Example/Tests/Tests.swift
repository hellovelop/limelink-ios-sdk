// Tests.swift - Entry point for LimelinkIOSSDK test suite
// Individual test files are located in Unit/ and Integration/ subdirectories.

import XCTest
@testable import LimelinkIOSSDK

class LimelinkIOSSDKSmokeTests: XCTestCase {

    func testSDKClassExists() {
        XCTAssertNotNil(LimeLinkSDK.shared)
    }
}
