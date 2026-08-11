import Foundation

public struct WebEndpoint: Hashable, Sendable {
    public let url: URL
    public let statusCode: Int
    public let contentType: String
    public let serverName: String?

    public init(url: URL, statusCode: Int, contentType: String, serverName: String?) {
        self.url = url.replacingLoopbackHostWithLocalhost
        self.statusCode = statusCode
        self.contentType = contentType
        self.serverName = serverName
    }

    public var isWebPage: Bool {
        let lowerType = contentType.lowercased()
        return lowerType.contains("text/html") || lowerType.contains("application/xhtml")
    }

    public var detail: String {
        if let serverName, !serverName.isEmpty {
            return serverName
        }
        return "HTML · HTTP \(statusCode)"
    }
}

private extension URL {
    var replacingLoopbackHostWithLocalhost: URL {
        guard host == "127.0.0.1" || host == "::1",
              var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        else {
            return self
        }
        components.host = "localhost"
        return components.url ?? self
    }
}
