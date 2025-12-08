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
        } else if host == "limelink.org" {
            // limelink.org 직접 접근 시 처리
            handleLimeLinkUniversalLink(url, completion: completion)
        } else {
            // 기존 deeplink 처리 로직
            let path = url.path  // 예: /abc123
            let subdomain = host.components(separatedBy: ".").first ?? ""
            let platform = "ios"
            
            fetchDeeplink(subdomain: subdomain, path: path, platform: platform, completion: completion)
        }
    }
    
    @objc public class func handleUniversalLink(_ url: URL, completion: @escaping (String?) -> Void) {
        shared.handleUniversalLink(url, completion: completion)
    }
    
    // MARK: - 기존 방식 (하위 호환성 유지) - Deprecated
    @available(*, deprecated, message: "Use handleUniversalLink(_:completion:) instead")
    @objc public func handleUniversalLink(_ url: URL) {
        handleUniversalLink(url) { uri in
            if let uri = uri {
                // 하위 호환성을 위해 NotificationCenter로 전달
                NotificationCenter.default.post(
                    name: Notification.Name("LimelinkDeepLinkReceived"),
                    object: nil,
                    userInfo: ["uri": uri, "url": url]
                )
            }
        }
    }
    
    @available(*, deprecated, message: "Use handleUniversalLink(_:completion:) instead")
    @objc public class func handleUniversalLink(_ url: URL) {
        shared.handleUniversalLink(url)
    }
    
    // MARK: - 서브도메인 패턴 처리 ({suffix}.limelink.org/link/{link_suffix})
    private func handleSubdomainPattern(_ url: URL, completion: @escaping (String?) -> Void) {
        guard let host = url.host else { 
            completion(nil)
            return 
        }
        
        // {suffix}.limelink.org에서 suffix 추출
        let suffix = host.replacingOccurrences(of: ".limelink.org", with: "")
        
        // URL 경로에서 link_suffix 추출 (/link/{link_suffix} 패턴)
        let path = url.path
        let linkPattern = #"^/link/(.+)$"#
        
        guard let regex = try? NSRegularExpression(pattern: linkPattern),
              let match = regex.firstMatch(in: path, range: NSRange(path.startIndex..., in: path)),
              let linkSuffixRange = Range(match.range(at: 1), in: path) else {
            print("❌ 서브도메인 패턴이 일치하지 않습니다: \(path)")
            // 패턴이 안 맞으면 suffix만으로 시도
            fetchUniversalLinkDirect(suffix: suffix, fullRequestUrl: url.absoluteString, completion: completion)
            return
        }
        
        let linkSuffix = String(path[linkSuffixRange])
        
        // 전체 요청 URL (쿼리 스트링 포함)
        let fullRequestUrl = url.absoluteString
        
        print("🔗 서브도메인 Universal Link 감지: \(host), suffix: \(suffix), linkSuffix: \(linkSuffix)")
        
        // 먼저 서브도메인에서 헤더 정보 가져오기
        fetchSubdomainHeaders(suffix: suffix) { [weak self] headers in
            guard let self = self else { 
                completion(nil)
                return 
            }
            
            // 헤더 정보를 사용하여 Universal Link API 호출
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
        
        // 첫 번째 패턴 시도
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: path, range: NSRange(path.startIndex..., in: path)),
           let suffixRange = Range(match.range(at: 1), in: path) {
            suffix = String(path[suffixRange])
        }
        
        // 두 번째 패턴 시도
        if suffix == nil,
           let regex = try? NSRegularExpression(pattern: apiPattern),
           let match = regex.firstMatch(in: path, range: NSRange(path.startIndex..., in: path)),
           let suffixRange = Range(match.range(at: 1), in: path) {
            suffix = String(path[suffixRange])
        }
        
        guard let linkSuffix = suffix else {
            print("❌ Universal Link 패턴이 일치하지 않습니다: \(path)")
            completion(nil)
            return
        }
        
        fetchUniversalLinkDirect(suffix: linkSuffix, fullRequestUrl: fullRequestUrl, completion: completion)
    }

    private func fetchDeeplink(subdomain: String, path: String, platform: String, completion: @escaping (String?) -> Void) {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        let urlString = "https://deep.limelink.org/link/subdomain=\(subdomain)&path=\(encodedPath)&platform=\(platform)"

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
                print("❌ Deeplink decoding error:", error)
                completion(nil)
            }
        }.resume()
    }
    
    // MARK: - 서브도메인 헤더 정보 가져오기
    private func fetchSubdomainHeaders(suffix: String, completion: @escaping ([String: String]) -> Void) {
        let urlString = "https://\(suffix).limelink.org"
        
        guard let url = URL(string: urlString) else {
            print("❌ 서브도메인 URL 생성 실패: \(urlString)")
            completion([:])
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD" // 헤더만 가져오기 위해 HEAD 요청 사용
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ 서브도메인 헤더 요청 실패: \(error)")
                completion([:])
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ HTTP 응답이 아닙니다")
                completion([:])
                return
            }
            
            // 응답 헤더 추출
            let headers = httpResponse.allHeaderFields as? [String: String] ?? [:]
            print("📋 서브도메인 헤더 정보: \(headers)")
            
            completion(headers)
        }.resume()
    }
    
    // MARK: - 헤더 정보를 포함한 Universal Link API 호출
    private func fetchUniversalLinkWithHeaders(linkSuffix: String, fullRequestUrl: String, headers: [String: String], completion: @escaping (String?) -> Void) {
        // URLComponents를 사용하여 쿼리 파라미터 추가
        var components = URLComponents(string: "https://www.limelink.org/api/v1/app/dynamic_link/\(linkSuffix)")!
        components.queryItems = [
            URLQueryItem(name: "full_request_url", value: fullRequestUrl)
        ]
        
        guard let url = components.url else {
            print("❌ Universal Link URL 생성 실패")
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 서브도메인에서 받은 헤더 정보를 요청에 포함
        for (key, value) in headers {
            // 중요한 헤더들만 전달 (보안상 민감한 정보 제외)
            if ["X-Request-ID", "X-User-Agent", "X-Referer", "X-Forwarded-For", "Authorization"].contains(key) {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        print("🔗 Universal Link API 호출: \(url.absoluteString)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Universal Link API 호출 실패: \(error)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("❌ Universal Link API 응답 데이터가 없습니다")
                completion(nil)
                return
            }
            
            do {
                let result = try JSONDecoder().decode(UniversalLinkResponse.self, from: data)
                print("✅ Universal Link URI 수신: \(result.uri)")
                DispatchQueue.main.async {
                    completion(result.uri)
                }
            } catch {
                print("❌ Universal Link 응답 디코딩 실패: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 응답 내용: \(responseString)")
                }
                completion(nil)
            }
        }.resume()
    }
    
    // MARK: - 직접 Universal Link API 호출 (헤더 없이)
    private func fetchUniversalLinkDirect(suffix: String, fullRequestUrl: String, completion: @escaping (String?) -> Void) {
        // URLComponents를 사용하여 쿼리 파라미터 추가
        var components = URLComponents(string: "https://www.limelink.org/api/v1/app/dynamic_link/\(suffix)")!
        components.queryItems = [
            URLQueryItem(name: "full_request_url", value: fullRequestUrl)
        ]
        
        guard let url = components.url else {
            print("❌ Universal Link URL 생성 실패")
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("🔗 Universal Link API 직접 호출: \(url.absoluteString)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Universal Link API 호출 실패: \(error)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("❌ Universal Link API 응답 데이터가 없습니다")
                completion(nil)
                return
            }
            
            do {
                let result = try JSONDecoder().decode(UniversalLinkResponse.self, from: data)
                print("✅ Universal Link URI 수신: \(result.uri)")
                DispatchQueue.main.async {
                    completion(result.uri)
                }
            } catch {
                print("❌ Universal Link 응답 디코딩 실패: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 응답 내용: \(responseString)")
                }
                completion(nil)
            }
        }.resume()
    }
}
