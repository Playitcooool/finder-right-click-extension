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

final class TahoeRequestServer {
    private let defaults = UserDefaults(suiteName: TahoeAppGroupIdentifier)
    private let writer = TahoeFileWriter(templateBundle: .main)

    init() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleCreateRequest(_:)),
            name: .TahoeCreateRequest,
            object: nil
        )
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func handleCreateRequest(_ notification: Notification) {
        guard let requestID = notification.userInfo?[TahoeRequestIdentifierKey] as? String,
              !requestID.isEmpty else {
            return
        }
        processRequest(requestID: requestID)
    }

    private func processRequest(requestID: String) {
        guard let defaults else {
            return
        }

        let requestKey = TahoeCreateRequestDefaultsKeyPrefix + requestID
        let responseKey = TahoeCreateResponseDefaultsKeyPrefix + requestID
        guard let request = defaults.dictionary(forKey: requestKey),
              let directoryPath = request[TahoeRequestDirectoryPathKey] as? String,
              let kindName = request[TahoeRequestKindKey] as? String else {
            return
        }

        NSLog("[TahoeHost] Processing create request id=%@ kind=%@ directory=%@", requestID, kindName, directoryPath)
        let scopedRootURL: URL
        do {
            scopedRootURL = try TahoeManagedRootsStore.bestMatchingManagedRootURL(forDirectoryPath: directoryPath)
        } catch {
            let response = [
                "success": false,
                "errorDescription": error.localizedDescription
            ] as [String : Any]
            defaults.set(response, forKey: responseKey)
            defaults.synchronize()
            return
        }

        let startedAccess = scopedRootURL.startAccessingSecurityScopedResource()
        NSLog("[TahoeHost] startAccessingSecurityScopedResource root=%@ started=%@", scopedRootURL.path, startedAccess ? "YES" : "NO")
        let result = writer.createDocument(atDirectoryPath: directoryPath, kindName: kindName)
        if startedAccess {
            scopedRootURL.stopAccessingSecurityScopedResource()
        }

        defaults.set(result, forKey: responseKey)
        defaults.synchronize()
    }
}

final class TahoeAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
