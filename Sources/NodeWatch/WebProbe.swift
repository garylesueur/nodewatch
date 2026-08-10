import Foundation
import NodeWatchCore

enum WebProbe {
    static func probe(_ services: [NodeService]) async -> [Int32: WebEndpoint] {
        await withTaskGroup(of: (Int32, WebEndpoint?).self) { group in
            for service in services where !service.ports.isEmpty {
                group.addTask { await (service.pid, firstWebPage(for: service.ports)) }
            }

            var result: [Int32: WebEndpoint] = [:]
            for await (pid, endpoint) in group {
                if let endpoint {
                    result[pid] = endpoint
                }
            }
            return result
        }
    }

    private static func firstWebPage(for ports: [Int]) async -> WebEndpoint? {
        for port in preferredOrder(ports) {
            guard let url = URL(string: "http://127.0.0.1:\(port)/") else { continue }
            var request = URLRequest(url: url, timeoutInterval: 0.8)
            request.httpMethod = "HEAD"
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("NodeWatch/0.1", forHTTPHeaderField: "User-Agent")

            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else { continue }
                let contentType = http.value(forHTTPHeaderField: "Content-Type") ?? ""
                guard (200 ..< 500).contains(http.statusCode) else { continue }
                return WebEndpoint(
                    url: url,
                    statusCode: http.statusCode,
                    contentType: contentType,
                    serverName: http.value(forHTTPHeaderField: "Server")
                )
            } catch {
                continue
            }
        }
        return nil
    }

    private static func preferredOrder(_ ports: [Int]) -> [Int] {
        ports.sorted { lhs, rhs in
            let lhsScore = portScore(lhs)
            let rhsScore = portScore(rhs)
            return lhsScore == rhsScore ? lhs < rhs : lhsScore < rhsScore
        }
    }

    private static func portScore(_ port: Int) -> Int {
        if (3000 ... 9999).contains(port) {
            return 0
        }
        if port == 80 || port == 443 {
            return 1
        }
        return 2
    }
}
