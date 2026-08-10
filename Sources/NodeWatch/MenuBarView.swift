import AppKit
import NodeWatchCore
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var store: ServiceStore
    @ObservedObject var updater: AppUpdater
    @Environment(\.openWindow) private var openWindow

    private var items: [NodeService] {
        store.treeOrdered(store.visibleServices)
    }

    private var hiddenHelperCount: Int {
        store.showHelpers ? 0 : store.services.filter { $0.kind == .helper }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("NodeWatch").font(.headline)
                    Text("\(items.count) process\(items.count == 1 ? "" : "es") · \(store.serverCount) servers")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
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
                    Image(systemName: "moon.zzz")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No development services running")
                        .font(.subheadline.weight(.medium))
                    Text("NodeWatch will keep checking in the background.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if hiddenHelperCount > 0 {
                        Button("Show \(hiddenHelperCount) hidden helper\(hiddenHelperCount == 1 ? "" : "s")") {
                            store.showHelpers = true
                        }
                        .controlSize(.small)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 130)
            } else {
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
                .frame(maxHeight: 520)
            }

            Divider()

            HStack {
                Button("Check for Updates…") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.isConfigured)

                Button("Show Main Window") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }

                Spacer()

                Button("Quit NodeWatch") { NSApp.terminate(nil) }
            }
            .padding(10)
        }
        .frame(width: 390)
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

    private func compactRow(_ service: NodeService) -> some View {
        HStack(spacing: 6) {
            Button {
                if store.webEndpoint(for: service) != nil {
                    store.open(service)
                }
            } label: {
                compactRowLabel(service)
            }
            .buttonStyle(.plain)
            .disabled(store.webEndpoint(for: service) == nil)
            .help(store.webEndpoint(for: service) == nil ? "No HTML page detected" : "Open in browser")

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
                        Text("\(endpoint.url.host ?? "localhost"):\(endpoint.url.port ?? 80)")
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
