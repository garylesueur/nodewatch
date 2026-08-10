import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: ServiceStore
    @ObservedObject var updater: AppUpdater
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section("Project roots") {
                Text(
                    "Processes running beneath these folders are treated as development projects. "
                        + "Enter one absolute path per line."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                TextEditor(text: $store.projectRootsText)
                    .font(.body.monospaced())
                    .frame(minHeight: 90)
                    .padding(5)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
            }

            Section("Runtime executables") {
                Text("Comma-separated executable names that NodeWatch should inspect.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("node, npm, pnpm, bun", text: $store.runtimeNamesText)
                    .textFieldStyle(.roundedBorder)
            }

            Section("Server command markers") {
                Text(
                    "A process is classified as a server when its command contains one of these "
                        + "comma-separated fragments."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                TextField("vite, expo, next", text: $store.serviceMarkersText)
                    .textFieldStyle(.roundedBorder)

                Toggle("Treat processes with listening TCP ports as servers", isOn: $store.treatListenersAsServers)
            }

            Section("Helper command markers") {
                Text("Matching processes are classified as helpers and can be hidden from the main list.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("language-server, prettier, logger", text: $store.helperMarkersText)
                    .textFieldStyle(.roundedBorder)
            }

            Section("Workload icons") {
                Text(
                    "Comma-separated command fragments used to infer mobile apps and AI agents. "
                        + "Confirmed HTML and HTTP endpoints are identified automatically as Web and API."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                LabeledContent("Mobile") {
                    TextField("expo, metro, react-native", text: $store.mobileMarkersText)
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent("Agent") {
                    TextField("agent, mcp, ai-sdk", text: $store.agentMarkersText)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Section("Behaviour") {
                Toggle("Show helper processes", isOn: $store.showHelpers)
                Toggle("Show CPU and memory usage", isOn: $store.showResourceUsage)
                Toggle("Probe localhost HTTP endpoints for clickable web pages", isOn: $store.probeWebServices)

                HStack {
                    Text("Refresh every")
                    Slider(value: $store.refreshInterval, in: 2 ... 30, step: 1)
                    Text("\(Int(store.refreshInterval))s")
                        .monospacedDigit()
                        .frame(width: 28, alignment: .trailing)
                }

                HStack {
                    TextField("Terminal application", text: $store.terminalAppPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Choose…") { chooseTerminalApplication() }
                }
            }

            Section("Updates") {
                LabeledContent("Version") {
                    Text(versionLabel)
                        .foregroundStyle(.secondary)
                }

                Button("Check for Updates…") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.isConfigured)

                if !updater.isConfigured {
                    Text("Automatic updates are disabled in this development build.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button("Reset Node/AI Defaults", role: .destructive) {
                    confirmReset = true
                }
                Spacer()
                Button("Refresh Now") {
                    Task { await store.refresh() }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 640, height: 820)
        .confirmationDialog(
            "Reset all detection and behaviour settings?",
            isPresented: $confirmReset,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) { store.resetConfiguration() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var versionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return build.map { "\(version) (\($0))" } ?? version
    }

    private func chooseTerminalApplication() {
        let panel = NSOpenPanel()
        panel.title = "Choose Terminal Application"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        if panel.runModal() == .OK, let url = panel.url {
            store.terminalAppPath = url.path
        }
    }
}
