//
//  PathParamResponse.swift
//  LimelinkIOSSDK
//
//  Created by artue on 6/24/24.
//

import Foundation

@objc public class PathParamResponse: NSObject {
    @objc public var mainPath: String
    @objc public var subPath: String?

    @objc public init(mainPath: String, subPath: String? = nil) {
        self.mainPath = mainPath
        self.subPath = subPath
        super.init()
    }

}
