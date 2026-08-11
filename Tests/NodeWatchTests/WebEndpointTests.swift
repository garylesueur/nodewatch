import Foundation
import NodeWatchCore
import Testing

@Suite("HTTP endpoint classification")
struct WebEndpointTests {
    @Test(
        "HTML responses are browser pages",
        arguments: ["text/html", "text/html; charset=utf-8", "application/xhtml+xml"]
    )
    func recognizesHTML(_ contentType: String) throws {
        let endpoint = try fixture(contentType: contentType)

        #expect(endpoint.isWebPage)
    }

    @Test("JSON responses are APIs")
    func rejectsJSONAsWebPage() throws {
        #expect(try !fixture(contentType: "application/json").isWebPage)
    }

    @Test("Server names provide concise endpoint details")
    func serverDetail() throws {
        #expect(try fixture(contentType: "text/html", serverName: "Vite").detail == "Vite")
    }

    @Test("Endpoint details fall back to HTTP status")
    func fallbackDetail() throws {
        #expect(try fixture(contentType: "text/html", statusCode: 404).detail == "HTML · HTTP 404")
        #expect(try fixture(contentType: "text/html", serverName: "").detail == "HTML · HTTP 200")
    }

    @Test("Loopback endpoints use localhost for display and browser launches")
    func normalizesLoopbackHost() throws {
        #expect(try fixture(contentType: "text/html").url == URL(string: "http://localhost:3000/"))

        let ipv6URL = try #require(URL(string: "http://[::1]:8080/api"))
        let endpoint = WebEndpoint(url: ipv6URL, statusCode: 200, contentType: "application/json", serverName: nil)
        #expect(endpoint.url == URL(string: "http://localhost:8080/api"))
    }

    private func fixture(
        contentType: String,
        statusCode: Int = 200,
        serverName: String? = nil
    ) throws -> WebEndpoint {
        let url = try #require(URL(string: "http://127.0.0.1:3000/"))
        return WebEndpoint(
            url: url,
            statusCode: statusCode,
            contentType: contentType,
            serverName: serverName
        )
    }
}
