import Foundation
import Sparkle

@MainActor
final class AppUpdater: ObservableObject {
    let isConfigured: Bool
    private let controller: SPUStandardUpdaterController?

    init(bundle: Bundle = .main) {
        let feedURL = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String
        let publicKey = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        let configured = [feedURL, publicKey].allSatisfy { value in
            guard let value else { return false }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        isConfigured = configured
        controller = configured
            ? SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
            : nil
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}
