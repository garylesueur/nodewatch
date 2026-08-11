import Foundation

public enum ProcessDetection {
    public static func isMonitored(command: String, runtimeNames: [String]) -> Bool {
        let executable = command.split(separator: " ").first.map(String.init) ?? ""
        let executableName = URL(fileURLWithPath: executable).lastPathComponent.lowercased()
        let configuredNames = Set(runtimeNames.map { $0.lowercased() })

        if configuredNames.contains(executableName) {
            return true
        }

        return executableName == "nodewatch" && isDebugBuildPath(executable)
    }

    private static func isDebugBuildPath(_ path: String) -> Bool {
        let components = URL(fileURLWithPath: path).pathComponents.map { $0.lowercased() }
        let debugComponent: (String) -> Bool = { component in
            component == "debug" || component.hasPrefix("debug-")
        }

        if let buildIndex = components.firstIndex(of: ".build") {
            return components.suffix(from: components.index(after: buildIndex)).contains(where: debugComponent)
        }

        return components.indices.contains { index in
            index + 2 < components.endIndex
                && components[index] == "build"
                && components[index + 1] == "products"
                && debugComponent(components[index + 2])
        }
    }
}
