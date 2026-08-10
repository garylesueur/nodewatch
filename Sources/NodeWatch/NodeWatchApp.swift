import SwiftUI

@main
struct NodeWatchApp: App {
    @StateObject private var store = ServiceStore()
    @StateObject private var updater = AppUpdater()

    var body: some Scene {
        Window("NodeWatch", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 760, minHeight: 420)
                .onAppear { store.start() }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 920, height: 560)

        MenuBarExtra {
            MenuBarView(store: store, updater: updater)
                .onAppear { store.start() }
        } label: {
            Label("\(store.serverCount)", systemImage: "server.rack")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(store: store, updater: updater)
        }

        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.isConfigured)
            }
        }
    }
}
