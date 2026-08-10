import AppKit
import Foundation
import NodeWatchCore

@MainActor
final class ServiceStore: ObservableObject {
    static let defaultRuntimeNames = "node, nodejs, npm, npx, pnpm, yarn, bun, deno"
    static let defaultServerMarkers = [
        "vite", "next", "expo", "metro", "webpack", "parcel", "nuxt", "astro", "nodemon",
        "tsx watch", "npm start", "pnpm start", "yarn start", "bun run", "deno run",
    ].joined(separator: ", ")
    static let defaultHelperMarkers = [
        "language-server", "language_server", "@roarr/cli", "prettier", "eslint", "codex", "cua_node", "node_repl",
    ].joined(separator: ", ")
    static let defaultMobileMarkers = "expo, metro, react-native"
    static let defaultAgentMarkers = "agent, mcp, model-context-protocol, ai-sdk"

    @Published var services: [NodeService] = []
    @Published var showHelpers: Bool {
        didSet { UserDefaults.standard.set(showHelpers, forKey: "display.showHelpers") }
    }

    @Published private(set) var hasCompletedInitialScan = false
    @Published var errorMessage: String?
    @Published var pendingTermination: NodeService?
    @Published var webEndpoints: [Int32: WebEndpoint] = [:]
    @Published var projectRootsText: String {
        didSet { UserDefaults.standard.set(projectRootsText, forKey: "projectRoots") }
    }

    @Published var serviceMarkersText: String {
        didSet { UserDefaults.standard.set(serviceMarkersText, forKey: "detection.serverMarkers") }
    }

    @Published var runtimeNamesText: String {
        didSet { UserDefaults.standard.set(runtimeNamesText, forKey: "detection.runtimeNames") }
    }

    @Published var helperMarkersText: String {
        didSet { UserDefaults.standard.set(helperMarkersText, forKey: "detection.helperMarkers") }
    }

    @Published var mobileMarkersText: String {
        didSet { UserDefaults.standard.set(mobileMarkersText, forKey: "presentation.mobileMarkers") }
    }

    @Published var agentMarkersText: String {
        didSet { UserDefaults.standard.set(agentMarkersText, forKey: "presentation.agentMarkers") }
    }

    @Published var treatListenersAsServers: Bool {
        didSet { UserDefaults.standard.set(treatListenersAsServers, forKey: "detection.listenersAreServers") }
    }

    @Published var refreshInterval: Double {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: "behavior.refreshInterval") }
    }

    @Published var terminalAppPath: String {
        didSet { UserDefaults.standard.set(terminalAppPath, forKey: "behavior.terminalAppPath") }
    }

    @Published var probeWebServices: Bool {
        didSet { UserDefaults.standard.set(probeWebServices, forKey: "behavior.probeWebServices") }
    }

    @Published var showResourceUsage: Bool {
        didSet { UserDefaults.standard.set(showResourceUsage, forKey: "display.showResourceUsage") }
    }

    private let scanner = ProcessScanner()
    private var refreshTask: Task<Void, Never>?
    private var refreshInProgress = false

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let defaults = UserDefaults.standard
        projectRootsText = UserDefaults.standard.string(forKey: "projectRoots")
            ?? "\(home)/dev\n\(home)/.codex/worktrees"
        runtimeNamesText = defaults.string(forKey: "detection.runtimeNames") ?? Self.defaultRuntimeNames
        serviceMarkersText = defaults.string(forKey: "detection.serverMarkers") ?? Self.defaultServerMarkers
        helperMarkersText = defaults.string(forKey: "detection.helperMarkers") ?? Self.defaultHelperMarkers
        mobileMarkersText = defaults.string(forKey: "presentation.mobileMarkers") ?? Self.defaultMobileMarkers
        agentMarkersText = defaults.string(forKey: "presentation.agentMarkers") ?? Self.defaultAgentMarkers
        treatListenersAsServers = defaults.object(forKey: "detection.listenersAreServers") as? Bool ?? true
        showHelpers = defaults.object(forKey: "display.showHelpers") as? Bool ?? false
        refreshInterval = defaults.object(forKey: "behavior.refreshInterval") as? Double ?? 5
        terminalAppPath = defaults.string(forKey: "behavior.terminalAppPath")
            ?? "/System/Applications/Utilities/Terminal.app"
        probeWebServices = defaults.object(forKey: "behavior.probeWebServices") as? Bool ?? true
        showResourceUsage = defaults.object(forKey: "display.showResourceUsage") as? Bool ?? true
    }

    var projectRoots: [String] {
        projectRootsText
            .split(whereSeparator: { $0.isNewline })
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var serverMarkers: [String] {
        serviceMarkersText
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var runtimeNames: [String] {
        commaSeparated(runtimeNamesText)
    }

    var helperMarkers: [String] {
        commaSeparated(helperMarkersText)
    }

    var mobileMarkers: [String] {
        commaSeparated(mobileMarkersText)
    }

    var agentMarkers: [String] {
        commaSeparated(agentMarkersText)
    }

    private func commaSeparated(_ text: String) -> [String] {
        text.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var visibleServices: [NodeService] {
        treeOrdered(services.filter { showHelpers || $0.kind != .helper })
    }

    var serverCount: Int {
        services.filter { $0.kind == .server }.count
    }

    func treeDepth(for service: NodeService, within items: [NodeService]) -> Int {
        ProcessTree.depth(for: service, within: items)
    }

    func treeOrdered(_ items: [NodeService]) -> [NodeService] {
        ProcessTree.ordered(items)
    }

    func start() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(self?.refreshInterval ?? 2))
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refresh() async {
        guard !refreshInProgress else { return }
        refreshInProgress = true
        defer { refreshInProgress = false }
        do {
            let scannedServices = try await scanner.scan(
                projectRoots: projectRoots,
                runtimeNames: runtimeNames,
                serverMarkers: serverMarkers,
                helperMarkers: helperMarkers,
                treatListenersAsServers: treatListenersAsServers
            )
            let probedEndpoints = probeWebServices ? await WebProbe.probe(scannedServices) : [:]
            let activePIDs = Set(scannedServices.map(\.pid))
            let retainedEndpoints = webEndpoints.filter { activePIDs.contains($0.key) }
            let stableEndpoints = retainedEndpoints.merging(probedEndpoints) { _, new in new }

            // Publish a completed scan only after endpoint probing finishes. SwiftUI
            // coalesces these synchronous changes into one stable menu update.
            webEndpoints = stableEndpoints
            services = scannedServices
            hasCompletedInitialScan = true
            errorMessage = nil
        } catch {
            hasCompletedInitialScan = true
            errorMessage = error.localizedDescription
        }
    }

    func open(_ service: NodeService) {
        guard let url = webEndpoints[service.pid]?.url else { return }
        NSWorkspace.shared.open(url)
    }

    func webEndpoint(for service: NodeService) -> WebEndpoint? {
        guard let endpoint = webEndpoints[service.pid], endpoint.isWebPage else { return nil }
        return endpoint
    }

    func httpEndpoint(for service: NodeService) -> WebEndpoint? {
        webEndpoints[service.pid]
    }

    func presentation(for service: NodeService) -> WorkloadPresentation {
        let command = service.command.lowercased()
        if mobileMarkers.map({ $0.lowercased() }).contains(where: command.contains)
            || hasMobileProjectConfig(service.workingDirectory)
        {
            return .mobile
        }
        if agentMarkers.map({ $0.lowercased() }).contains(where: command.contains) {
            return .agent
        }
        if webEndpoint(for: service) != nil {
            return .web
        }
        if webEndpoints[service.pid] != nil {
            return .api
        }
        if service.kind == .helper {
            return .tool
        }
        return .process
    }

    private func hasMobileProjectConfig(_ directory: String?) -> Bool {
        guard let directory else { return false }
        let candidates = ["app.json", "app.config.js", "app.config.ts", "app.config.mjs"]
        return candidates.contains { name in
            FileManager.default.fileExists(atPath: URL(fileURLWithPath: directory).appendingPathComponent(name).path)
        }
    }

    func reveal(_ service: NodeService) {
        guard let path = service.workingDirectory else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    func openTerminal(_ service: NodeService) {
        guard let path = service.workingDirectory else { return }
        let folderURL = URL(fileURLWithPath: path)
        let terminalURL = URL(fileURLWithPath: terminalAppPath)
        guard FileManager.default.fileExists(atPath: terminalAppPath) else {
            errorMessage = "Terminal application not found at \(terminalAppPath). Choose it in Settings."
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open(
            [folderURL],
            withApplicationAt: terminalURL,
            configuration: configuration
        ) { [weak self] _, error in
            if let error {
                Task { @MainActor in self?.errorMessage = error.localizedDescription }
            }
        }
    }

    func resetConfiguration() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        projectRootsText = "\(home)/dev\n\(home)/.codex/worktrees"
        runtimeNamesText = Self.defaultRuntimeNames
        serviceMarkersText = Self.defaultServerMarkers
        helperMarkersText = Self.defaultHelperMarkers
        mobileMarkersText = Self.defaultMobileMarkers
        agentMarkersText = Self.defaultAgentMarkers
        treatListenersAsServers = true
        showHelpers = false
        refreshInterval = 5
        terminalAppPath = "/System/Applications/Utilities/Terminal.app"
        probeWebServices = true
        showResourceUsage = true
        Task { await refresh() }
    }

    func requestTermination(of service: NodeService) {
        pendingTermination = service
    }

    func confirmTermination() {
        guard let service = pendingTermination else { return }
        pendingTermination = nil
        if Darwin.kill(service.pid, SIGTERM) != 0 {
            errorMessage = String(cString: strerror(errno))
        }
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            await refresh()
        }
    }
}
