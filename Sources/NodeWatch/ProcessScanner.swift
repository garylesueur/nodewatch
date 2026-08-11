import Foundation
import NodeWatchCore

actor ProcessScanner {
    private struct RawProcess: Sendable {
        let pid: Int32
        let parentPID: Int32
        let percentCPU: Double
        let residentMemoryBytes: Int64
        let uptime: String
        let command: String
    }

    func scan(
        projectRoots: [String],
        runtimeNames: [String],
        serverMarkers: [String],
        helperMarkers: [String],
        treatListenersAsServers: Bool
    ) async throws -> [NodeService] {
        let processOutput = try run("/bin/ps", ["-axo", "pid=,ppid=,%cpu=,rss=,etime=,command="])
        let processes = processOutput
            .split(separator: "\n")
            .compactMap(parseProcess)
            .filter { ProcessDetection.isMonitored(command: $0.command, runtimeNames: runtimeNames) }

        guard !processes.isEmpty else { return [] }

        let pidSet = Set(processes.map(\.pid))
        let ports = try listeningPorts(for: pidSet)
        let directories = try workingDirectories(for: pidSet)

        return processes.map { process in
            let processPorts = ports[process.pid, default: []].sorted()
            return NodeService(
                pid: process.pid,
                parentPID: process.parentPID,
                percentCPU: process.percentCPU,
                residentMemoryBytes: process.residentMemoryBytes,
                uptime: process.uptime,
                command: process.command,
                workingDirectory: directories[process.pid],
                ports: processPorts,
                kind: classify(
                    command: process.command,
                    workingDirectory: directories[process.pid],
                    hasPorts: !processPorts.isEmpty,
                    projectRoots: projectRoots,
                    serverMarkers: serverMarkers,
                    helperMarkers: helperMarkers,
                    treatListenersAsServers: treatListenersAsServers
                ),
                name: displayName(for: process.command)
            )
        }
        .sorted {
            if $0.kind != $1.kind {
                return kindRank($0.kind) < kindRank($1.kind)
            }
            if $0.projectName != $1.projectName {
                return $0.projectName < $1.projectName
            }
            return $0.pid < $1.pid
        }
    }

    private func parseProcess(_ line: Substring) -> RawProcess? {
        let parts = line.split(maxSplits: 5, whereSeparator: \Character.isWhitespace)
        guard parts.count == 6,
              let pid = Int32(parts[0]),
              let parentPID = Int32(parts[1]),
              let percentCPU = Double(parts[2]),
              let residentMemoryKB = Int64(parts[3]) else { return nil }
        return RawProcess(
            pid: pid,
            parentPID: parentPID,
            percentCPU: percentCPU,
            residentMemoryBytes: residentMemoryKB * 1024,
            uptime: String(parts[4]),
            command: String(parts[5])
        )
    }

    private func listeningPorts(for pids: Set<Int32>) throws -> [Int32: [Int]] {
        let output = try run("/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:LISTEN", "-Fpn"])
        var result: [Int32: Set<Int>] = [:]
        var currentPID: Int32?

        for line in output.split(separator: "\n").map(String.init) {
            if line.first == "p" {
                currentPID = Int32(line.dropFirst())
            } else if line.first == "n", let pid = currentPID, pids.contains(pid),
                      let port = parsePort(from: String(line.dropFirst()))
            {
                result[pid, default: []].insert(port)
            }
        }
        return result.mapValues { Array($0) }
    }

    private func parsePort(from endpoint: String) -> Int? {
        guard let colon = endpoint.lastIndex(of: ":") else { return nil }
        let value = endpoint[endpoint.index(after: colon)...]
            .split(separator: " ").first.map(String.init) ?? ""
        return Int(value)
    }

    private func workingDirectories(for pids: Set<Int32>) throws -> [Int32: String] {
        let list = pids.sorted().map(String.init).joined(separator: ",")
        let output = try run("/usr/sbin/lsof", ["-a", "-p", list, "-d", "cwd", "-Fpn"])
        var result: [Int32: String] = [:]
        var currentPID: Int32?

        for line in output.split(separator: "\n").map(String.init) {
            if line.first == "p" {
                currentPID = Int32(line.dropFirst())
            } else if line.first == "n", let pid = currentPID {
                result[pid] = String(line.dropFirst())
            }
        }
        return result
    }

    private func classify(
        command: String,
        workingDirectory: String?,
        hasPorts: Bool,
        projectRoots: [String],
        serverMarkers: [String],
        helperMarkers: [String],
        treatListenersAsServers: Bool
    ) -> NodeService.Kind {
        let lower = command.lowercased()
        // Explicit server commands and listening processes win over path-based helper
        // detection. A real Expo process may legitimately live in a Codex worktree.
        if (treatListenersAsServers && hasPorts)
            || serverMarkers.map({ $0.lowercased() }).contains(where: lower.contains)
        {
            return .server
        }

        if helperMarkers.map({ $0.lowercased() }).contains(where: lower.contains) {
            return .helper
        }

        if let workingDirectory,
           projectRoots.contains(where: { isDescendant(workingDirectory, of: $0) })
        {
            return .process
        }
        return .process
    }

    private func isDescendant(_ path: String, of root: String) -> Bool {
        let normalizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        let normalizedRoot = URL(fileURLWithPath: root).standardizedFileURL.path
        return normalizedPath == normalizedRoot || normalizedPath.hasPrefix(normalizedRoot + "/")
    }

    private func displayName(for command: String) -> String {
        let lower = command.lowercased()
        let names: [(String, String)] = [
            ("nodewatch", "NodeWatch"),
            ("vite", "Vite"), ("next", "Next.js"), ("expo", "Expo / Metro"),
            ("metro", "Metro"), ("webpack", "Webpack"), ("parcel", "Parcel"),
            ("nuxt", "Nuxt"), ("astro", "Astro"), ("nodemon", "Nodemon"),
            ("language-server", "Language Server"), ("@roarr/cli", "Roarr Logger"),
            ("node_repl", "Node REPL"),
        ]
        return names.first(where: { lower.contains($0.0) })?.1 ?? "Node"
    }

    private func kindRank(_ kind: NodeService.Kind) -> Int {
        switch kind {
        case .server: 0
        case .process: 1
        case .helper: 2
        }
    }

    private func run(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = errorPipe
        try process.run()
        // Drain stdout while the child is running. Waiting first can deadlock when a
        // large process table fills the pipe buffer (common on development Macs).
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let message = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ScannerError.commandFailed(executable, message)
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    enum ScannerError: LocalizedError {
        case commandFailed(String, String)

        var errorDescription: String? {
            switch self {
            case let .commandFailed(command, message):
                "\(command) failed: \(message)"
            }
        }
    }
}
