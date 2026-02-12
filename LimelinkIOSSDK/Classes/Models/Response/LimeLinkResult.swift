//
//  LimeLinkResult.swift
//  LimelinkIOSSDK
//

import Foundation

@objc public class LimeLinkResult: NSObject {
    @objc public let originalUrl: String?
    @objc public let resolvedUri: String?
    @objc public let queryParams: [String: String]
    @objc public let pathParams: PathParamResponse
    @objc public let isDeferred: Bool

    @objc public init(
        originalUrl: String? = nil,
        resolvedUri: String? = nil,
        queryParams: [String: String] = [:],
        pathParams: PathParamResponse = PathParamResponse(mainPath: ""),
        isDeferred: Bool = false
    ) {
        self.originalUrl = originalUrl
        self.resolvedUri = resolvedUri
        self.queryParams = queryParams
        self.pathParams = pathParams
        self.isDeferred = isDeferred
        super.init()
    }
}
