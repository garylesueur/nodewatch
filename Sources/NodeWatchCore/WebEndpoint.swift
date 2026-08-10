import Foundation

public struct WebEndpoint: Hashable, Sendable {
    public let url: URL
    public let statusCode: Int
    public let contentType: String
    public let serverName: String?

    public init(url: URL, statusCode: Int, contentType: String, serverName: String?) {
        self.url = url
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
