import XCTest
@testable import LimelinkIOSSDK

class PathParamResponseTests: XCTestCase {

    func test_init_withBothParams() {
        let response = PathParamResponse(mainPath: "main", subPath: "sub")
        XCTAssertEqual(response.mainPath, "main")
        XCTAssertEqual(response.subPath, "sub")
    }

    func test_init_defaultSubPathIsNil() {
        let response = PathParamResponse(mainPath: "main")
        XCTAssertEqual(response.mainPath, "main")
        XCTAssertNil(response.subPath)
    }

    func test_mainPathAndSubPathCombinations() {
        let r1 = PathParamResponse(mainPath: "", subPath: nil)
        XCTAssertEqual(r1.mainPath, "")
        XCTAssertNil(r1.subPath)

        let r2 = PathParamResponse(mainPath: "path", subPath: "detail")
        XCTAssertEqual(r2.mainPath, "path")
        XCTAssertEqual(r2.subPath, "detail")
    }
}
