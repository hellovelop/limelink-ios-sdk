import Foundation
import XCTest

class MockURLProtocol: URLProtocol {
    static var requestHandlers: [String: (URLRequest) throws -> (HTTPURLResponse, Data?)] = [:]
    static var capturedRequests: [URLRequest] = []
    private static let lock = NSLock()

    static func reset() {
        lock.lock()
        requestHandlers = [:]
        capturedRequests = []
        lock.unlock()
    }

    static func addCapturedRequest(_ request: URLRequest) {
        lock.lock()
        capturedRequests.append(request)
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    /// Read the HTTP body from a URLRequest, falling back to httpBodyStream if httpBody is nil
    /// (URLProtocol converts httpBody to httpBodyStream)
    static func bodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data.isEmpty ? nil : data
    }

    override func startLoading() {
        MockURLProtocol.addCapturedRequest(request)

        guard let url = request.url?.absoluteString else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "MockURLProtocol", code: -1, userInfo: [NSLocalizedDescriptionKey: "No URL"]))
            return
        }

        // Find a matching handler by checking if the URL contains the key
        // Use longest match to avoid ambiguous pattern collisions
        var matchedHandler: ((URLRequest) throws -> (HTTPURLResponse, Data?))? = nil
        var longestMatch = 0
        for (pattern, handler) in MockURLProtocol.requestHandlers {
            if url.contains(pattern) && pattern.count > longestMatch {
                matchedHandler = handler
                longestMatch = pattern.count
            }
        }

        guard let handler = matchedHandler else {
            // Default: return 404
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data = data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
