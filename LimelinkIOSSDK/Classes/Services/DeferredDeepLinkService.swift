import Foundation
import UIKit

public class DeferredDeepLinkService {
    private static let baseURL = "https://limelink.org/api/v1"
    
    // MARK: - 디퍼드 딥링크 조회 (핑거프린팅 방식)
    public static func getDeferredDeepLink(
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // 1. 디바이스 정보 수집
        let deviceInfo = getDeviceInfo()
        
        // 2. 디퍼드 딥링크 API로 suffix 조회
        fetchSuffix(deviceInfo: deviceInfo) { result in
            switch result {
            case .success(let suffix):
                // 3. suffix로 dynamic_link API 호출
                fetchDynamicLink(suffix: suffix, completion: completion)
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - 디바이스 정보 수집
    private static func getDeviceInfo() -> DeviceInfo {
        let screen = UIScreen.main.bounds
        let device = UIDevice.current
        
        // user_agent 생성: "iOS 18_7" 형식
        let osName = device.systemName        // "iOS"
        let osVersion = device.systemVersion.replacingOccurrences(of: ".", with: "_")  // "18.7" -> "18_7"
        let userAgent = "\(osName) \(osVersion)"
        
        return DeviceInfo(
            width: Int(screen.width),
            height: Int(screen.height),
            userAgent: userAgent
        )
    }
    
    // MARK: - Suffix 조회
    private static func fetchSuffix(
        deviceInfo: DeviceInfo,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // URL 쿼리 파라미터 생성
        var components = URLComponents(string: "\(baseURL)/deferred-deep-link")!
        components.queryItems = [
            URLQueryItem(name: "width", value: String(deviceInfo.width)),
            URLQueryItem(name: "height", value: String(deviceInfo.height)),
            URLQueryItem(name: "user_agent", value: deviceInfo.userAgent)
        ]
        
        guard let url = components.url else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "Invalid response", code: 0, userInfo: nil)))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "No data", code: httpResponse.statusCode, userInfo: nil)))
                return
            }
            
            if httpResponse.statusCode == 200 {
                do {
                    let result = try JSONDecoder().decode(SuffixResponse.self, from: data)
                    
                    if let suffix = result.suffix {
                        completion(.success(suffix))
                    } else {
                        // suffix가 없으면 디퍼드 딥링크 매칭 실패
                        completion(.failure(NSError(domain: "No matching deferred deep link", code: 404, userInfo: nil)))
                    }
                } catch {
                    completion(.failure(error))
                }
            } else {
                completion(.failure(NSError(domain: "API Error", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? "Unknown error"])))
            }
        }.resume()
    }
    
    // MARK: - Dynamic Link 조회 (UniversalLink와 동일한 방식)
    private static func fetchDynamicLink(
        suffix: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let urlString = "https://www.limelink.org/api/v1/dynamic_link/\(suffix)"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "Invalid response", code: 0, userInfo: nil)))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "No data", code: httpResponse.statusCode, userInfo: nil)))
                return
            }
            
            if httpResponse.statusCode == 200 {
                do {
                    let result = try JSONDecoder().decode(DynamicLinkResponse.self, from: data)
                    completion(.success(result.uri))
                } catch {
                    completion(.failure(error))
                }
            } else {
                completion(.failure(NSError(domain: "API Error", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? "Unknown error"])))
            }
        }.resume()
    }
}

// MARK: - Models

private struct DeviceInfo {
    let width: Int
    let height: Int
    let userAgent: String
}

private struct SuffixResponse: Codable {
    let suffix: String?
}

private struct DynamicLinkResponse: Codable {
    let uri: String
}
