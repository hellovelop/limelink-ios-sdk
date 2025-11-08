import Foundation

public class GetDeferredDeepLinkByTokenResponse: Codable {
    public var parameters: [String: Any]?
    public var ios_app_store_url: String?
    public var android_play_store_url: String?
    public var fallback_url: String?
    
    enum CodingKeys: String, CodingKey {
        case parameters
        case ios_app_store_url
        case android_play_store_url
        case fallback_url
    }
    
    // Custom decoding for parameters dictionary
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ios_app_store_url = try container.decodeIfPresent(String.self, forKey: .ios_app_store_url)
        android_play_store_url = try container.decodeIfPresent(String.self, forKey: .android_play_store_url)
        fallback_url = try container.decodeIfPresent(String.self, forKey: .fallback_url)
        
        // Decode parameters as JSON object and convert to dictionary
        if let parametersDict = try? container.decodeIfPresent([String: AnyCodable].self, forKey: .parameters) {
            var dict: [String: Any] = [:]
            for (key, value) in parametersDict {
                dict[key] = value.value
            }
            parameters = dict
        }
    }
    
    // Custom encoding for parameters dictionary
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(ios_app_store_url, forKey: .ios_app_store_url)
        try container.encodeIfPresent(android_play_store_url, forKey: .android_play_store_url)
        try container.encodeIfPresent(fallback_url, forKey: .fallback_url)
        
        if let parameters = parameters {
            let jsonData = try JSONSerialization.data(withJSONObject: parameters)
            let jsonString = String(data: jsonData, encoding: .utf8)
            try container.encodeIfPresent(jsonString, forKey: .parameters)
        }
    }
}

