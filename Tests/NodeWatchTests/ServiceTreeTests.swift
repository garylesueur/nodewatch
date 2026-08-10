import NodeWatchCore
import Testing

@Suite("Process tree")
struct ServiceTreeTests {
    @Test("Children follow their monitored parent")
    @MainActor
    func ordersParentBeforeChild() {
        let parent = fixture(pid: 100, parentPID: 1)
        let child = fixture(pid: 101, parentPID: 100)
        let unrelated = fixture(pid: 200, parentPID: 1)

        let ordered = ProcessTree.ordered([child, parent, unrelated])

        #expect(ordered.map(\.pid) == [100, 101, 200])
        #expect(ProcessTree.depth(for: parent, within: ordered) == 0)
        #expect(ProcessTree.depth(for: child, within: ordered) == 1)
    }

    @Test("Cycles cannot create infinite nesting")
    @MainActor
    func handlesMalformedCycles() {
        let first = fixture(pid: 10, parentPID: 11)
        let second = fixture(pid: 11, parentPID: 10)

        #expect(ProcessTree.depth(for: first, within: [first, second]) == 1)
        #expect(ProcessTree.ordered([first, second]).map(\.pid) == [10, 11])
    }

    @Test("Nested descendants retain stable input order")
    func ordersNestedDescendants() {
        let root = fixture(pid: 100, parentPID: 1)
        let firstChild = fixture(pid: 101, parentPID: 100)
        let grandchild = fixture(pid: 102, parentPID: 101)
        let secondChild = fixture(pid: 103, parentPID: 100)

        let ordered = ProcessTree.ordered([root, firstChild, grandchild, secondChild])

        #expect(ordered.map(\.pid) == [100, 101, 102, 103])
        #expect(ProcessTree.depth(for: grandchild, within: ordered) == 2)
    }

    private func fixture(pid: Int32, parentPID: Int32) -> NodeService {
        NodeService(
            pid: pid,
            parentPID: parentPID,
            percentCPU: 0,
            residentMemoryBytes: 0,
            uptime: "00:01",
            command: "node fixture.js",
            workingDirectory: nil,
            ports: [],
            kind: .process,
            name: "Node"
        )
    }
}
