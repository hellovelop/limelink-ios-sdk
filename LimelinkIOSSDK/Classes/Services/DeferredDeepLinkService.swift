import Foundation

public class DeferredDeepLinkService {
    private static let baseURL = "https://limelink.org/api/v1"
    
    // MARK: - 토큰 중복 확인 (인증 불필요)
    public static func checkToken(
        token: String,
        completion: @escaping (Result<CheckTokenResponse, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/deferred-deep-link/check-token?token=\(token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? token)") else {
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
                    let result = try JSONDecoder().decode(CheckTokenResponse.self, from: data)
                    completion(.success(result))
                } catch {
                    completion(.failure(error))
                }
            } else {
                completion(.failure(NSError(domain: "API Error", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? "Unknown error"])))
            }
        }.resume()
    }
    
    // MARK: - 토큰으로 파라미터 조회 (앱 설치 후 첫 실행 시 사용, 인증 불필요)
    public static func getDeferredDeepLinkByToken(
        token: String,
        completion: @escaping (Result<GetDeferredDeepLinkByTokenResponse, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/deferred-deep-link/token/\(token.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? token)") else {
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
                    let result = try JSONDecoder().decode(GetDeferredDeepLinkByTokenResponse.self, from: data)
                    completion(.success(result))
                } catch {
                    completion(.failure(error))
                }
            } else {
                completion(.failure(NSError(domain: "API Error", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? "Unknown error"])))
            }
        }.resume()
    }
}

