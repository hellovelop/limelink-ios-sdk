import Foundation

public class CheckTokenResponse: Codable {
    public var is_exist: Bool
    
    public init(is_exist: Bool) {
        self.is_exist = is_exist
    }
}

