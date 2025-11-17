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

    @objc public func handleUniversalLink(_ url: URL, completion: @escaping (String?) -> Void) {
        guard let host = url.host else { 
            completion(nil)
            return 
        }
        
        // {suffix}.limelink.org/link/{link_suffix} 패턴 처리
        if host.hasSuffix(".limelink.org") {
            handleSubdomainPattern(url, completion: completion)
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
    
    
    // MARK: - 서브도메인 패턴 처리 ({suffix}.limelink.org/link/{link_suffix})
    private func handleSubdomainPattern(_ url: URL, completion: @escaping (String?) -> Void) {
        guard let host = url.host else { return }
        
        // {suffix}.limelink.org에서 suffix 추출
        let suffix = host.replacingOccurrences(of: ".limelink.org", with: "")
        
        // URL 경로에서 link_suffix 추출 (/link/{link_suffix} 패턴)
        let path = url.path
        let linkPattern = #"^/link/(.+)$"#
        
        guard let regex = try? NSRegularExpression(pattern: linkPattern),
              let match = regex.firstMatch(in: path, range: NSRange(path.startIndex..., in: path)),
              let linkSuffixRange = Range(match.range(at: 1), in: path) else {
            print("❌ 서브도메인 패턴이 일치하지 않습니다: \(path)")
            completion(nil)
            return
        }
        
        let linkSuffix = String(path[linkSuffixRange])
        
        // 먼저 서브도메인에서 헤더 정보 가져오기
        fetchSubdomainHeaders(suffix: suffix) { [weak self] headers in
            guard let self = self else { return }
            
            // 헤더 정보를 사용하여 Universal Link API 호출
            self.fetchUniversalLinkWithHeaders(suffix: suffix, linkSuffix: linkSuffix, headers: headers) { uri in
                completion(uri)
            }
        }
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

    private func navigateToDeeplink(_ deeplink: String) {
        guard let deeplinkURL = URL(string: deeplink) else { return }

        // 내부 라우팅: 앱 구조에 맞춰 수정
        // 예: myapp://screen/123 → 딥링크 처리
        UIApplication.shared.open(deeplinkURL, options: [:], completionHandler: nil)
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
    private func fetchUniversalLinkWithHeaders(suffix: String, linkSuffix: String, headers: [String: String], completion: @escaping (String?) -> Void) {
        let urlString = "https://www.limelink.org//api/v1/app/dynamic_link/\(linkSuffix)"
        
        guard let url = URL(string: urlString) else {
            print("❌ Universal Link URL 생성 실패: \(urlString)")
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
