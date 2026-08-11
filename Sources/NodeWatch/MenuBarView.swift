import AppKit
import NodeWatchCore
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var store: ServiceStore
    @ObservedObject var updater: AppUpdater
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    private var items: [NodeService] {
        store.treeOrdered(store.visibleServices)
    }

    private var serverSummary: String {
        if store.serverCount == 0 {
            return "No servers running"
        }
        return "\(store.serverCount) server\(store.serverCount == 1 ? "" : "s") running"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("NodeWatch").font(.headline)
                    Text(serverSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                WorkloadFilterMenu(store: store, showTitle: false)
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                SettingsLink {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help("Settings")

                Button {
                    Task { await store.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh now")
            }
            .padding(12)

            Divider()

            if items.isEmpty {
                VStack(spacing: 9) {
                    Image(systemName: "server.rack")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No servers running")
                        .font(.subheadline.weight(.medium))
                    Text(emptyStateDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if store.hiddenServiceCount > 0 {
                        Button(
                            "Show all \(store.hiddenServiceCount) hidden "
                                + "service\(store.hiddenServiceCount == 1 ? "" : "s")"
                        ) {
                            store.showAllPresentations()
                        }
                        .controlSize(.small)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 174)
            } else {
                VStack(spacing: 0) {
                    if store.serverCount == 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                            Text("No servers running. Other Node.js processes are shown below.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                        Divider()
                    }

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(items) { service in
                                compactRow(service)
                                if service.id != items.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
                .frame(minHeight: 174, maxHeight: 520, alignment: .top)
            }

            Divider()

            HStack(spacing: 8) {
                Button {
                    openMainWindow()
                } label: {
                    Label("Open NodeWatch", systemImage: "macwindow")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Spacer()

                Menu {
                    Button("Check for Updates…", systemImage: "arrow.triangle.2.circlepath") {
                        updater.checkForUpdates()
                    }
                    .disabled(!updater.isConfigured)

                    Divider()

                    Button("Quit NodeWatch", systemImage: "power", role: .destructive) {
                        NSApp.terminate(nil)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("More actions")
            }
            .padding(10)
        }
        .frame(width: 410)
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
                Text("This sends SIGTERM to PID \(service.pid).")
            }
        }
    }

    private var emptyStateDescription: String {
        if store.hiddenServiceCount > 0 {
            return "The current type filter hides \(store.hiddenServiceCount) "
                + "service\(store.hiddenServiceCount == 1 ? "" : "s")."
        }
        return "NodeWatch will keep checking in the background."
    }

    private func openMainWindow() {
        dismiss()
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            NSApp.windows.first(where: \.canBecomeMain)?.makeKeyAndOrderFront(nil)
        }
    }

    private func compactRow(_ service: NodeService) -> some View {
        HStack(spacing: 6) {
            Group {
                if store.webEndpoint(for: service) != nil {
                    Button {
                        store.open(service)
                    } label: {
                        compactRowLabel(service)
                    }
                    .buttonStyle(.plain)
                    .help("Open in browser")
                } else {
                    compactRowLabel(service)
                }
            }

            Menu {
                if store.webEndpoint(for: service) != nil {
                    Button("Open in Browser", systemImage: "safari") { store.open(service) }
                }
                Button("Open Terminal Here", systemImage: "terminal") { store.openTerminal(service) }
                Button("Reveal in Finder", systemImage: "folder") { store.reveal(service) }
                Divider()
                Button("Stop Process", systemImage: "xmark.circle", role: .destructive) {
                    store.requestTermination(of: service)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private func compactRowLabel(_ service: NodeService) -> some View {
        HStack(spacing: 10) {
            if depth(for: service) > 0 {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .frame(width: 10)
            }
            Image(systemName: store.presentation(for: service).symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor(for: service))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(service.projectName)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text(service.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(store.presentation(for: service).rawValue.uppercased())
                        .font(.system(size: 8, weight: .semibold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(.secondary.opacity(0.12), in: Capsule())
                }
                HStack(spacing: 5) {
                    if let endpoint = store.webEndpoint(for: service) {
                        Text("localhost:\(endpoint.url.port ?? 80)")
                        Text("· \(endpoint.detail)")
                    } else if let endpoint = store.httpEndpoint(for: service) {
                        Text("localhost:\(endpoint.url.port ?? 80)")
                        Text("· \(endpoint.contentType.split(separator: ";").first ?? "HTTP")")
                    } else {
                        Text(service.ports
                            .isEmpty ? "PID \(service.pid)" : "ports \(service.portLabel) · PID \(service.pid)")
                    }
                    if store.showResourceUsage {
                        Text("· CPU \(service.cpuLabel) · \(service.memoryLabel)")
                    }
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
            Spacer()
            if store.webEndpoint(for: service) != nil {
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.leading, CGFloat(max(0, depth(for: service) - 1)) * 16)
        .contentShape(Rectangle())
    }

    private func depth(for service: NodeService) -> Int {
        store.treeDepth(for: service, within: items)
    }

    private func iconColor(for service: NodeService) -> Color {
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
