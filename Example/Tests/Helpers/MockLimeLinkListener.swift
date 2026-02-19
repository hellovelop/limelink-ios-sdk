import Foundation
import XCTest
@testable import LimelinkIOSSDK

class MockLimeLinkListener: NSObject, LimeLinkListener {
    var receivedResults: [LimeLinkResult] = []
    var receivedErrors: [LimeLinkError] = []

    var onResultExpectation: XCTestExpectation?
    var onErrorExpectation: XCTestExpectation?

    func onDeeplinkReceived(result: LimeLinkResult) {
        receivedResults.append(result)
        onResultExpectation?.fulfill()
    }

    func onDeeplinkError(error: LimeLinkError) {
        receivedErrors.append(error)
        onErrorExpectation?.fulfill()
    }

    func reset() {
        receivedResults = []
        receivedErrors = []
        onResultExpectation = nil
        onErrorExpectation = nil
    }
}
