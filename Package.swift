// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "LimelinkIOSSDK",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "LimelinkIOSSDK",
            targets: ["LimelinkIOSSDK", "LimelinkIOSSDKObjC"]
        ),
    ],
    targets: [
        .target(
            name: "LimelinkIOSSDK",
            path: "LimelinkIOSSDK/Classes",
            exclude: ["ObjCBridge"]
        ),
        .target(
            name: "LimelinkIOSSDKObjC",
            dependencies: ["LimelinkIOSSDK"],
            path: "LimelinkIOSSDK/Classes/ObjCBridge",
            publicHeadersPath: "."
        ),
    ]
)
