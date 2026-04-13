import AppKit
import FinderSync
import Foundation

enum TahoeHostSupport {
    static let installedHostPath = "/Applications/TahoeNewFileHost.app"

    static func hostBundleURL() -> URL {
        Bundle.main.bundleURL
    }

    static func preferredHostBundleURL() -> URL {
        let installedURL = URL(fileURLWithPath: installedHostPath, isDirectory: true)
        if FileManager.default.fileExists(atPath: installedURL.path) {
            return installedURL
        }
        return hostBundleURL()
    }

    static func extensionBundleURL() -> URL {
        preferredHostBundleURL()
            .appendingPathComponent("Contents/PlugIns", isDirectory: true)
            .appendingPathComponent("TahoeFinderSync.appex", isDirectory: true)
    }

    static func restartFinder() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Finder"]
        try process.run()
        process.waitUntilExit()
    }

    static func registerExtension() throws {
        try runProcess(
            executablePath: "/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister",
            arguments: ["-f", "-R", "-trusted", preferredHostBundleURL().path]
        )
        try runProcess(
            executablePath: "/usr/bin/pluginkit",
            arguments: ["-a", extensionBundleURL().path]
        )
    }

    static var isRunningInstalledCopy: Bool {
        hostBundleURL().standardizedFileURL == preferredHostBundleURL().standardizedFileURL
    }

    static func openExtensionSettings() {
        FIFinderSyncController.showExtensionManagementInterface()
    }

    static var extensionEnabled: Bool {
        FIFinderSyncController.isExtensionEnabled
    }

    private static func runProcess(executablePath: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let stderrPipe = Pipe()
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(
                domain: NSCocoaErrorDomain,
                code: Int(process.terminationStatus),
                userInfo: [
                    NSLocalizedDescriptionKey: message?.isEmpty == false
                        ? message!
                        : "系统扩展注册失败。"
                ]
            )
        }
    }
}
