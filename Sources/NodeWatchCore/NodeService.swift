import Foundation

public enum WorkloadPresentation: String, Sendable {
    case web = "Web"
    case mobile = "Mobile"
    case api = "API"
    case agent = "Agent"
    case tool = "Tool"
    case process = "Process"

    public var symbol: String {
        switch self {
        case .web: "safari"
        case .mobile: "iphone"
        case .api: "curlybraces"
        case .agent: "cpu"
        case .tool: "wrench.and.screwdriver"
        case .process: "shippingbox"
        }
    }
}

public struct NodeService: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable {
        case server = "Server"
        case helper = "Helper"
        case process = "Process"
    }

    public let pid: Int32
    public let parentPID: Int32
    public let percentCPU: Double
    public let residentMemoryBytes: Int64
    public let uptime: String
    public let command: String
    public let workingDirectory: String?
    public let ports: [Int]
    public let kind: Kind
    public let name: String

    public init(
        pid: Int32,
        parentPID: Int32,
        percentCPU: Double,
        residentMemoryBytes: Int64,
        uptime: String,
        command: String,
        workingDirectory: String?,
        ports: [Int],
        kind: Kind,
        name: String
    ) {
        self.pid = pid
        self.parentPID = parentPID
        self.percentCPU = percentCPU
        self.residentMemoryBytes = residentMemoryBytes
        self.uptime = uptime
        self.command = command
        self.workingDirectory = workingDirectory
        self.ports = ports
        self.kind = kind
        self.name = name
    }

    public var id: Int32 {
        pid
    }

    public var projectName: String {
        guard let workingDirectory, !workingDirectory.isEmpty else { return "Unknown project" }
        return URL(fileURLWithPath: workingDirectory).lastPathComponent
    }

    public var portLabel: String {
        ports.map(String.init).joined(separator: ", ")
    }

    public var primaryURL: URL? {
        guard let port = ports.first else { return nil }
        return URL(string: "http://localhost:\(port)")
    }

    public var memoryLabel: String {
        ByteCountFormatter.string(fromByteCount: residentMemoryBytes, countStyle: .memory)
    }

    public var cpuLabel: String {
        percentCPU < 0.1 ? "0%" : String(format: "%.1f%%", percentCPU)
    }
}
