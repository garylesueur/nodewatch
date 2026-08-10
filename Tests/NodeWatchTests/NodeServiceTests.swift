import Foundation
import NodeWatchCore
import Testing

@Suite("Node service model")
struct NodeServiceTests {
    @Test("A listening service exposes its first local URL")
    func primaryURL() {
        let service = fixture(pid: 42, ports: [3000, 8081])

        #expect(service.primaryURL == URL(string: "http://localhost:3000"))
        #expect(service.portLabel == "3000, 8081")
    }

    @Test("A process without ports has no local URL")
    func missingURL() {
        #expect(fixture(pid: 42).primaryURL == nil)
    }

    @Test("Project names come from the working directory")
    func projectName() {
        #expect(fixture(pid: 42, workingDirectory: "/Users/example/Projects/nodewatch").projectName == "nodewatch")
        #expect(fixture(pid: 43, workingDirectory: nil).projectName == "Unknown project")
        #expect(fixture(pid: 44, workingDirectory: "").projectName == "Unknown project")
    }

    @Test("CPU labels suppress sampling noise and retain useful precision")
    func cpuLabel() {
        #expect(fixture(pid: 42, percentCPU: 0.09).cpuLabel == "0%")
        #expect(fixture(pid: 43, percentCPU: 12.34).cpuLabel == "12.3%")
    }

    @Test(
        "Workload types have distinct symbols",
        arguments: [
            WorkloadPresentation.web,
            .mobile,
            .api,
            .agent,
            .tool,
            .process,
        ]
    )
    func workloadSymbolsArePresent(_ presentation: WorkloadPresentation) {
        #expect(!presentation.symbol.isEmpty)
    }

    private func fixture(
        pid: Int32,
        parentPID: Int32 = 1,
        percentCPU: Double = 1.5,
        workingDirectory: String? = "/tmp/example",
        ports: [Int] = []
    ) -> NodeService {
        NodeService(
            pid: pid,
            parentPID: parentPID,
            percentCPU: percentCPU,
            residentMemoryBytes: 64 * 1024 * 1024,
            uptime: "00:10",
            command: "node server.js",
            workingDirectory: workingDirectory,
            ports: ports,
            kind: .server,
            name: "Node"
        )
    }
}
