//
//  LinkStats.swift
//  LimelinkIOSSDK
//
//  Created by artue on 6/24/24.
//

import Foundation

public class LinkStats {
    private static let keyFirstLaunch = "is_first_launch"

    public static func isFirstLaunch() -> Bool {
        let userDefaults = UserDefaults.standard
        // UserDefaults.bool(forKey:) returns false when key doesn't exist,
        // so we use object(forKey:) == nil to detect first launch
        if userDefaults.object(forKey: keyFirstLaunch) == nil {
            userDefaults.set(false, forKey: keyFirstLaunch)
            return true
        }
        return false
    }
}

func createLimeLinkRequest(privateKey: String, pathParamResponse: PathParamResponse, eventType: EventType) -> LimeLinkRequest {
    return LimeLinkRequest(
        private_key: privateKey,
        suffix: pathParamResponse.mainPath,
        handle: pathParamResponse.subPath,
        event_type: eventType.rawValue
    )
}

@available(*, deprecated, message: "Use LimeLinkSDK.shared.trackLinkStatus(url:) instead")
public func saveLimeLinkStatus(url: URL?, privateKey: String) {
    saveLimeLinkStatusInternal(url: url, privateKey: privateKey, eventType: nil)
}

func saveLimeLinkStatusInternal(url: URL?, privateKey: String, eventType: EventType? = nil) {
    let pathParamResponse = parsePathParams(from: url)

    if pathParamResponse.mainPath.isEmpty {
        return
    }

    let resolvedEventType = eventType ?? .RERUN
    let limeLinkRequest = createLimeLinkRequest(privateKey: privateKey, pathParamResponse: pathParamResponse, eventType: resolvedEventType)

    sendLimeLink(data: limeLinkRequest) { result in
        switch result {
        case .success:
            break
        case .failure:
            break
        }
    }
}

func sendLimeLink(data: LimeLinkRequest, completion: @escaping (Result<Void, Error>) -> Void) {
    let configBaseUrl = LimeLinkSDK.shared.config?.baseUrl ?? "https://limelink.org/"
    let baseURL = URL(string: configBaseUrl)!
    let url = baseURL.appendingPathComponent("api/v1/stats/event")
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    do {
        let jsonData = try JSONEncoder().encode(data)
        request.httpBody = jsonData
    } catch {
        completion(.failure(error))
        return
    }

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            completion(.failure(error))
            return
        }

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            completion(.failure(NSError(domain: "Invalid response", code: 0, userInfo: nil)))
            return
        }

        completion(.success(()))
    }

    task.resume()
}
