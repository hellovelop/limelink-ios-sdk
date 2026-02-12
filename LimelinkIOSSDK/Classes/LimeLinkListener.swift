//
//  LimeLinkListener.swift
//  LimelinkIOSSDK
//

import Foundation

@objc public protocol LimeLinkListener: AnyObject {
    @objc func onDeeplinkReceived(result: LimeLinkResult)
    @objc optional func onDeeplinkError(error: LimeLinkError)
}
