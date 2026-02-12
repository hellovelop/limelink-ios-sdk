import Foundation
import UIKit

struct DeeplinkResponse: Codable {
    let deeplinkUrl: String
}

struct UniversalLinkResponse: Codable {
    let uri: String
}

@objc public class UniversalLink: NSObject {
    @objc public static let shared = UniversalLink()

    private override init() {
        super.init()
    }

    // MARK: - Completion Handler 방식 (권장)
    @objc public func handleUniversalLink(_ url: URL, completion: @escaping (String?) -> Void) {
        guard let host = url.host else {
            completion(nil)
            return
        }

        // {suffix}.limelink.org/link/{link_suffix} 패턴 처리
        if host.hasSuffix(".limelink.org") {
            handleSubdomainPattern(url, completion: completion)
        } else if host == "limelink.org" || host == "www.limelink.org" {
            // limelink.org 직접 접근 시 처리
            handleLimeLinkUniversalLink(url, completion: completion)
        } else {
            // 기존 deeplink 처리 로직
            let path = url.path
            let subdomain = host.components(separatedBy: ".").first ?? ""
            let platform = "ios"

            fetchDeeplink(subdomain: subdomain, path: path, platform: platform, completion: completion)
        }
    }

    @objc public class func handleUniversalLink(_ url: URL, completion: @escaping (String?) -> Void) {
        shared.handleUniversalLink(url, completion: completion)
    }

    // MARK: - 기존 방식 (하위 호환성 유지) - Deprecated
    @available(*, deprecated, message: "Use LimeLinkSDK.shared.handleUniversalLink(_:) or handleUniversalLink(_:completion:) instead")
    @objc public func handleUniversalLink(_ url: URL) {
        handleUniversalLink(url) { uri in
            if let uri = uri {
                NotificationCenter.default.post(
                    name: Notification.Name("LimelinkDeepLinkReceived"),
                    object: nil,
                    userInfo: ["uri": uri, "url": url]
                )
            }
        }
    }

    @available(*, deprecated, message: "Use LimeLinkSDK.shared.handleUniversalLink(_:) or handleUniversalLink(_:completion:) instead")
    @objc public class func handleUniversalLink(_ url: URL) {
        shared.handleUniversalLink(url)
    }

    // MARK: - 서브도메인 패턴 처리 ({suffix}.limelink.org/link/{link_suffix})
    private func handleSubdomainPattern(_ url: URL, completion: @escaping (String?) -> Void) {
        guard let host = url.host else {
            completion(nil)
            return
        }

        let suffix = host.replacingOccurrences(of: ".limelink.org", with: "")
        let path = url.path
        let linkPattern = #"^/link/(.+)$"#

        guard let regex = try? NSRegularExpression(pattern: linkPattern),
              let match = regex.firstMatch(in: path, range: NSRange(path.startIndex..., in: path)),
              let linkSuffixRange = Range(match.range(at: 1), in: path) else {
            // 패턴이 안 맞으면 suffix만으로 시도
            fetchUniversalLinkDirect(suffix: suffix, fullRequestUrl: url.absoluteString, completion: completion)
            return
        }

        let linkSuffix = String(path[linkSuffixRange])
        let fullRequestUrl = url.absoluteString

        fetchSubdomainHeaders(suffix: suffix) { [weak self] headers in
            guard let self = self else {
                completion(nil)
                return
            }

            self.fetchUniversalLinkWithHeaders(linkSuffix: linkSuffix, fullRequestUrl: fullRequestUrl, headers: headers, completion: completion)
        }
    }

    // MARK: - LimeLink Universal Link 처리 (직접 접근)
    private func handleLimeLinkUniversalLink(_ url: URL, completion: @escaping (String?) -> Void) {
        let path = url.path
        let fullRequestUrl = url.absoluteString

        // /universal-link/app/dynamic_link/{suffix} 패턴 확인
        let pattern = #"^/universal-link/app/dynamic_link/(.+)$"#
        // /api/v1/app/dynamic_link/{suffix} 패턴도 확인
        let apiPattern = #"^/api/v1/app/dynamic_link/(.+)$"#

        var suffix: String? = nil

        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: path, range: NSRange(path.startIndex..., in: path)),
           let suffixRange = Range(match.range(at: 1), in: path) {
            suffix = String(path[suffixRange])
        }

        if suffix == nil,
           let regex = try? NSRegularExpression(pattern: apiPattern),
           let match = regex.firstMatch(in: path, range: NSRange(path.startIndex..., in: path)),
           let suffixRange = Range(match.range(at: 1), in: path) {
            suffix = String(path[suffixRange])
        }

        guard let linkSuffix = suffix else {
            completion(nil)
            return
        }

        fetchUniversalLinkDirect(suffix: linkSuffix, fullRequestUrl: fullRequestUrl, completion: completion)
    }

    // MARK: - Legacy Deeplink
    private func fetchDeeplink(subdomain: String, path: String, platform: String, completion: @escaping (String?) -> Void) {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://deep.limelink.org/link?subdomain=\(subdomain)&path=\(encodedPath)&platform=\(platform)"

        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard error == nil, let data = data else {
                completion(nil)
                return
            }

            do {
                let result = try JSONDecoder().decode(DeeplinkResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(result.deeplinkUrl)
                }
            } catch {
                completion(nil)
            }
        }.resume()
    }

    // MARK: - 서브도메인 헤더 정보 가져오기
    private func fetchSubdomainHeaders(suffix: String, completion: @escaping ([String: String]) -> Void) {
        let urlString = "https://\(suffix).limelink.org"

        guard let url = URL(string: urlString) else {
            completion([:])
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"

        URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                completion([:])
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion([:])
                return
            }

            let headers = httpResponse.allHeaderFields as? [String: String] ?? [:]
            completion(headers)
        }.resume()
    }

    // MARK: - 헤더 정보를 포함한 Universal Link API 호출
    private func fetchUniversalLinkWithHeaders(linkSuffix: String, fullRequestUrl: String, headers: [String: String], completion: @escaping (String?) -> Void) {
        let baseUrl = LimeLinkSDK.shared.config?.baseUrl ?? "https://limelink.org/"
        let apiBase = baseUrl.hasSuffix("/") ? baseUrl + "api/v1" : baseUrl + "/api/v1"
        var components = URLComponents(string: "\(apiBase)/app/dynamic_link/\(linkSuffix)")!
        components.queryItems = [
            URLQueryItem(name: "full_request_url", value: fullRequestUrl)
        ]

        guard let url = components.url else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        for (key, value) in headers {
            if ["X-Request-ID", "X-User-Agent", "X-Referer", "X-Forwarded-For", "Authorization"].contains(key) {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                completion(nil)
                return
            }

            guard let data = data else {
                completion(nil)
                return
            }

            do {
                let result = try JSONDecoder().decode(UniversalLinkResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(result.uri)
                }
            } catch {
                completion(nil)
            }
        }.resume()
    }

    // MARK: - 직접 Universal Link API 호출 (헤더 없이)
    private func fetchUniversalLinkDirect(suffix: String, fullRequestUrl: String, completion: @escaping (String?) -> Void) {
        let baseUrl = LimeLinkSDK.shared.config?.baseUrl ?? "https://limelink.org/"
        let apiBase = baseUrl.hasSuffix("/") ? baseUrl + "api/v1" : baseUrl + "/api/v1"
        var components = URLComponents(string: "\(apiBase)/app/dynamic_link/\(suffix)")!
        components.queryItems = [
            URLQueryItem(name: "full_request_url", value: fullRequestUrl)
        ]

        guard let url = components.url else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                completion(nil)
                return
            }

            guard let data = data else {
                completion(nil)
                return
            }

            do {
                let result = try JSONDecoder().decode(UniversalLinkResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(result.uri)
                }
            } catch {
                completion(nil)
            }
        }.resume()
    }

    private func navigateToDeeplink(_ deeplink: String) {
        guard let deeplinkURL = URL(string: deeplink) else { return }
        UIApplication.shared.open(deeplinkURL, options: [:], completionHandler: nil)
    }
}
