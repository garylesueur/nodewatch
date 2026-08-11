import NodeWatchCore
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ServiceStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if store.visibleServices.isEmpty, store.hasCompletedInitialScan {
                if !store.services.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "eye.slash").font(.largeTitle).foregroundStyle(.secondary)
                        Text("No services match the displayed types")
                            .font(.headline)
                        Text(
                            "\(store.hiddenServiceCount) service"
                                + "\(store.hiddenServiceCount == 1 ? " is" : "s are") hidden"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        Button("Show All Types") { store.showAllPresentations() }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView(
                        "No matching processes found",
                        systemImage: "shippingbox",
                        description: Text("NodeWatch will check again automatically.")
                    )
                }
            } else {
                serviceList
            }

            if let error = store.errorMessage {
                Divider()
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error).lineLimit(2)
                    Spacer()
                }
                .font(.caption)
                .padding(10)
                .background(.orange.opacity(0.08))
            }
        }
        .confirmationDialog(
            "Stop \(store.pendingTermination?.name ?? "service")?",
            isPresented: Binding(
                get: { store.pendingTermination != nil },
                set: {
                    if !$0 {
                        store.pendingTermination = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Stop Process", role: .destructive) { store.confirmTermination() }
            Button("Cancel", role: .cancel) { store.pendingTermination = nil }
        } message: {
            if let service = store.pendingTermination {
                Text("This sends SIGTERM to PID \(service.pid), allowing it to shut down gracefully.")
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("NodeWatch")
                    .font(.title2.bold())
                Text("\(store.serverCount) server\(store.serverCount == 1 ? "" : "s") running")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            WorkloadFilterMenu(store: store, showTitle: true)

            SettingsLink {
                Image(systemName: "gearshape")
            }
            .help("Detection settings")

            Button {
                Task { await store.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh now")
        }
        .padding(16)
    }

    private var serviceList: some View {
        List(store.visibleServices) { service in
            ServiceRow(service: service, store: store)
                .listRowSeparator(.visible)
                .padding(.vertical, 5)
        }
        .listStyle(.inset)
    }
}

struct WorkloadFilterMenu: View {
    @ObservedObject var store: ServiceStore
    let showTitle: Bool

    var body: some View {
        Menu {
            ForEach(WorkloadPresentation.allCases, id: \.self) { presentation in
                Toggle(
                    presentation.rawValue,
                    isOn: Binding(
                        get: { store.isPresentationVisible(presentation) },
                        set: { store.setPresentation(presentation, isVisible: $0) }
                    )
                )
            }

            Divider()

            Button("Show All") { store.showAllPresentations() }
        } label: {
            if showTitle {
                Label("Types", systemImage: "line.3.horizontal.decrease.circle")
            } else {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
        }
        .help("Choose displayed workload types")
    }
}

private struct ServiceRow: View {
    let service: NodeService
    @ObservedObject var store: ServiceStore

    var body: some View {
        HStack(spacing: 12) {
            if depth > 0 {
                Image(systemName: "arrow.turn.down.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(width: 14)
            }
            statusIcon

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(service.name).font(.headline)
                    Text(store.presentation(for: service).rawValue.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.12), in: Capsule())
                    if !service.ports.isEmpty {
                        Text("localhost:\(service.portLabel)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.blue)
                    }
                    if store.showResourceUsage {
                        resourceBadge(service.cpuLabel, symbol: "gauge.with.dots.needle.33percent")
                        resourceBadge(service.memoryLabel, symbol: "memorychip")
                    }
                }

                Text(service.projectName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("PID \(service.pid)  •  up \(service.uptime)  •  \(service.command)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            if store.webEndpoint(for: service) != nil {
                Button("Open") { store.open(service) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }

            Button {
                store.openTerminal(service)
            } label: {
                Image(systemName: "terminal")
            }
            .buttonStyle(.borderless)
            .help("Open Terminal here")
            .disabled(service.workingDirectory == nil)

            Button {
                store.reveal(service)
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .help("Reveal project in Finder")
            .disabled(service.workingDirectory == nil)

            Button {
                store.requestTermination(of: service)
            } label: {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help("Stop process")
        }
        .padding(.leading, CGFloat(max(0, depth - 1)) * 22)
    }

    private var depth: Int {
        store.treeDepth(for: service, within: store.visibleServices)
    }

    private func resourceBadge(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 10, weight: .medium).monospacedDigit())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.secondary.opacity(0.09), in: Capsule())
    }

    private var statusIcon: some View {
        ZStack {
            Circle().fill(color.opacity(0.13)).frame(width: 38, height: 38)
            Image(systemName: store.presentation(for: service).symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    private var color: Color {
        switch store.presentation(for: service) {
        case .web: .blue
        case .mobile: .purple
        case .api: .orange
        case .agent: .mint
        case .tool: .gray
        case .process: .secondary
        }
    }
}
