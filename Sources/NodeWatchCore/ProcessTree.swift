public enum ProcessTree {
    public static func depth(for service: NodeService, within items: [NodeService]) -> Int {
        let byPID = Dictionary(uniqueKeysWithValues: items.map { ($0.pid, $0) })
        var depth = 0
        var parentPID = service.parentPID
        var visited: Set<Int32> = [service.pid]
        while let parent = byPID[parentPID], !visited.contains(parent.pid), depth < 8 {
            visited.insert(parent.pid)
            depth += 1
            parentPID = parent.parentPID
        }
        return depth
    }

    public static func ordered(_ items: [NodeService]) -> [NodeService] {
        let ids = Set(items.map(\.pid))
        let children = Dictionary(grouping: items.filter { ids.contains($0.parentPID) }, by: \.parentPID)
        let roots = items.filter { !ids.contains($0.parentPID) }
        var result: [NodeService] = []
        var visited: Set<Int32> = []

        func append(_ item: NodeService) {
            guard visited.insert(item.pid).inserted else { return }
            result.append(item)
            for child in children[item.pid, default: []] {
                append(child)
            }
        }
        for root in roots {
            append(root)
        }
        // Malformed process snapshots can contain parent cycles. Preserve those
        // services after the valid trees instead of silently dropping them.
        for item in items where !visited.contains(item.pid) {
            append(item)
        }
        return result
    }
}
