//
//  LimeLinkSDK.swift
//  LimelinkIOSSDK
//

import Foundation
import UIKit

@objc public class LimeLinkSDK: NSObject {
    @objc public static let shared = LimeLinkSDK()

    private(set) var config: LimeLinkConfig?
    private var listeners = NSHashTable<AnyObject>.weakObjects()
    private var _isInitialized = false

    @objc public var isInitialized: Bool {
        return _isInitialized
    }

    private override init() {
        super.init()
    }

    // MARK: - Initialization

    @objc public static func initialize(config: LimeLinkConfig) {
        let sdk = LimeLinkSDK.shared
        guard !sdk._isInitialized else {
            sdk.log("LimeLinkSDK is already initialized.")
            return
        }
        sdk.config = config
        sdk._isInitialized = true
        sdk.log("LimeLinkSDK initialized with baseUrl: \(config.baseUrl)")

        // Auto-check deferred deep link on first launch
        if config.deferredDeeplinkEnabled && LinkStats.isFirstLaunch() {
            sdk.log("First launch detected. Checking deferred deep link...")
            sdk.checkDeferredDeepLink()
        }
    }

    // MARK: - Listener Management

    @objc public func addLinkListener(_ listener: LimeLinkListener) {
        listeners.add(listener as AnyObject)
    }

    @objc public func removeLinkListener(_ listener: LimeLinkListener) {
        listeners.remove(listener as AnyObject)
    }

    // MARK: - Universal Link Handling

    @objc public func handleUniversalLink(_ url: URL) {
        guard _isInitialized, let config = config else {
            log("LimeLinkSDK not initialized. Call LimeLinkSDK.initialize(config:) first.")
            notifyError(LimeLinkError(code: -1, message: "SDK not initialized"))
            return
        }

        log("Handling universal link: \(url.absoluteString)")

        UniversalLink.shared.handleUniversalLink(url) { [weak self] uri in
            guard let self = self else { return }

            if let uri = uri {
                let queryParams = parseQueryParams(from: url)
                let pathParams = parsePathParams(from: url)

                let result = LimeLinkResult(
                    originalUrl: url.absoluteString,
                    resolvedUri: uri,
                    queryParams: queryParams,
                    pathParams: pathParams,
                    isDeferred: false
                )
                self.notifyResult(result)

                // Track stats
                saveLimeLinkStatusInternal(url: URL(string: uri), privateKey: config.apiKey)
            } else {
                self.notifyError(LimeLinkError(
                    code: 404,
                    message: "Failed to resolve universal link: \(url.absoluteString)"
                ))
            }
        }
    }

    // MARK: - Deferred Deep Link

    @objc public func handleDeferredDeepLink(completion: ((LimeLinkResult?, LimeLinkError?) -> Void)? = nil) {
        guard _isInitialized, let config = config else {
            let error = LimeLinkError(code: -1, message: "SDK not initialized")
            completion?(nil, error)
            notifyError(error)
            return
        }

        log("Checking deferred deep link...")

        DeferredDeepLinkService.getDeferredDeepLinkWithDetail(baseUrl: config.baseUrl) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let info):
                // full_request_url에서 queryParams 파싱
                var queryParams: [String: String] = [:]
                if let originalUrlString = info.originalUrl,
                   let originalURL = URL(string: originalUrlString) {
                    let components = URLComponents(url: originalURL, resolvingAgainstBaseURL: false)
                    components?.queryItems?.forEach { queryParams[$0.name] = $0.value ?? "" }
                }

                let linkResult = LimeLinkResult(
                    originalUrl: info.originalUrl,
                    resolvedUri: info.uri,
                    queryParams: queryParams,
                    pathParams: PathParamResponse(mainPath: ""),
                    isDeferred: true
                )
                self.notifyResult(linkResult)
                completion?(linkResult, nil)

            case .failure(let error):
                let linkError = LimeLinkError(
                    code: (error as NSError).code,
                    message: error.localizedDescription,
                    underlyingError: error
                )
                self.notifyError(linkError)
                completion?(nil, linkError)
            }
        }
    }

    // MARK: - Stats Tracking

    @objc public func trackLinkStatus(url: URL?) {
        guard _isInitialized, let config = config else {
            log("LimeLinkSDK not initialized.")
            return
        }
        saveLimeLinkStatusInternal(url: url, privateKey: config.apiKey)
    }

    // MARK: - Private Helpers

    private func checkDeferredDeepLink() {
        handleDeferredDeepLink(completion: nil)
    }

    private func notifyResult(_ result: LimeLinkResult) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            for case let listener as LimeLinkListener in self.listeners.allObjects {
                listener.onDeeplinkReceived(result: result)
            }
        }
    }

    private func notifyError(_ error: LimeLinkError) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            for case let listener as LimeLinkListener in self.listeners.allObjects {
                listener.onDeeplinkError?(error: error)
            }
        }
    }

    func log(_ message: String) {
        guard config?.loggingEnabled == true else { return }
        print("[LimeLinkSDK] \(message)")
    }

    #if DEBUG
    internal func resetForTesting() {
        _isInitialized = false
        config = nil
        listeners = NSHashTable<AnyObject>.weakObjects()
    }
    #endif
}
