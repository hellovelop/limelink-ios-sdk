//
//  limelink_exampleApp.swift
//  limelink-example
//
//  Created by dotdot on 2/12/26.
//

import SwiftUI

@main
struct limelink_exampleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // Handle universal links through SDK
                    LimeLinkSDK.shared.handleUniversalLink(url)
                }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, LimeLinkListener {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Initialize LimeLink SDK
        let config = LimeLinkConfig(
            apiKey: "YOUR_API_KEY",
            loggingEnabled: true,
            deferredDeeplinkEnabled: true
        )
        LimeLinkSDK.initialize(config: config)

        // Register listener
        LimeLinkSDK.shared.addLinkListener(self)

        return true
    }

    // Handle universal links via UIApplicationDelegate
    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return false
        }
        LimeLinkSDK.shared.handleUniversalLink(url)
        return true
    }

    // MARK: - LimeLinkListener

    func onDeeplinkReceived(result: LimeLinkResult) {
        print("Deeplink received!")
        print("  Original URL: \(result.originalUrl ?? "nil")")
        print("  Resolved URI: \(result.resolvedUri ?? "nil")")
        print("  Is Deferred: \(result.isDeferred)")
        print("  Query Params: \(result.queryParams)")
    }

    func onDeeplinkError(error: LimeLinkError) {
        print("Deeplink error: \(error.message)")
    }
}
