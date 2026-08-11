import NodeWatchCore
import Testing

@Suite("Process detection")
struct ProcessDetectionTests {
    @Test("Configured runtime executable names are matched case-insensitively")
    func configuredRuntime() {
        #expect(ProcessDetection.isMonitored(command: "/usr/local/bin/Node server.js", runtimeNames: ["node"]))
        #expect(!ProcessDetection.isMonitored(command: "/usr/bin/python3 server.py", runtimeNames: ["node"]))
    }

    @Test("SwiftPM NodeWatch debug builds are monitored")
    func swiftPackageDebugBuild() {
        let command = "/Users/example/nodewatch/.build/arm64-apple-macosx/debug/NodeWatch"

        #expect(ProcessDetection.isMonitored(command: command, runtimeNames: []))
    }

    @Test("Xcode NodeWatch debug builds are monitored")
    func xcodeDebugBuild() {
        let command = "/Users/example/Library/Developer/Xcode/DerivedData/NodeWatch/Build/Products/Debug/NodeWatch"

        #expect(ProcessDetection.isMonitored(command: command, runtimeNames: []))
    }

    @Test("Release and installed NodeWatch builds are not monitored automatically")
    func nonDebugBuilds() {
        let releaseCommand = "/Users/example/nodewatch/.build/arm64-apple-macosx/release/NodeWatch"
        let installedCommand = "/Applications/NodeWatch.app/Contents/MacOS/NodeWatch"

        #expect(!ProcessDetection.isMonitored(command: releaseCommand, runtimeNames: []))
        #expect(!ProcessDetection.isMonitored(command: installedCommand, runtimeNames: []))
    }
}
