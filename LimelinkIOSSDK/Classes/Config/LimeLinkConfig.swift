//
//  LimeLinkConfig.swift
//  LimelinkIOSSDK
//

import Foundation

@objc public class LimeLinkConfig: NSObject {
    @objc public let apiKey: String
    @objc public let baseUrl: String
    @objc public let loggingEnabled: Bool
    @objc public let deferredDeeplinkEnabled: Bool

    @objc public init(
        apiKey: String,
        baseUrl: String = "https://limelink.org/",
        loggingEnabled: Bool = false,
        deferredDeeplinkEnabled: Bool = true
    ) {
        self.apiKey = apiKey
        self.baseUrl = baseUrl.hasSuffix("/") ? baseUrl : baseUrl + "/"
        self.loggingEnabled = loggingEnabled
        self.deferredDeeplinkEnabled = deferredDeeplinkEnabled
        super.init()
    }
}
