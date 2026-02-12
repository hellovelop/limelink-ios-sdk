//
//  LimeLinkError.swift
//  LimelinkIOSSDK
//

import Foundation

@objc public class LimeLinkError: NSObject, LocalizedError {
    @objc public let code: Int
    @objc public let message: String
    @objc public let underlyingError: Error?

    @objc public init(code: Int, message: String, underlyingError: Error? = nil) {
        self.code = code
        self.message = message
        self.underlyingError = underlyingError
        super.init()
    }

    public var errorDescription: String? {
        return message
    }

    override public var description: String {
        return "LimeLinkError(code: \(code), message: \(message))"
    }
}
