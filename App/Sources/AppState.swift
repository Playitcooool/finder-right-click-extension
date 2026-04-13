import AppKit
import Foundation

@MainActor
final class TahoeAppState: ObservableObject {
    @Published var status: String = "先启用 Finder 扩展，再添加要接管右键菜单的目录。位置在系统设置的 Finder Extensions，不是 File Provider。"
    @Published var managedPaths: [String] = []
    @Published var extensionEnabled: Bool = false

    init() {
        refresh()
    }

    var extensionPath: String {
        TahoeHostSupport.extensionBundleURL().path
    }

    func refresh() {
        managedPaths = TahoeManagedRootsStore.managedDirectoryPaths()
        extensionEnabled = TahoeHostSupport.extensionEnabled
        if !TahoeHostSupport.isRunningInstalledCopy {
            status = "当前打开的不是 /Applications 里的正式副本。系统注册会统一指向 /Applications/TahoeNewFileHost.app。"
        } else if managedPaths.isEmpty {
            status = extensionEnabled
                ? "扩展已启用。下一步请添加至少一个受控目录。"
                : "扩展还没启用。先打开系统扩展管理页，在 Finder Extensions 里启用它。"
        }
    }

    func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Add Folder"
        panel.message = "只有这里添加过的目录及其子目录，才会在 Finder 空白处右键出现新建菜单。"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try addManagedFolder(url)
            refresh()
            status = "已添加受控目录。必要时点一次 Restart Finder。"
        } catch {
            status = error.localizedDescription
        }
    }

    func removeFolder(path: String) {
        TahoeManagedRootsStore.removeManagedDirectory(atPath: path)
        refresh()
        status = managedPaths.isEmpty ? "已移除全部受控目录。" : "已移除受控目录。"
    }

    func clearFolders() {
        TahoeManagedRootsStore.removeAllManagedDirectories()
        refresh()
        status = "已清空受控目录。"
    }

    func openExtensionSettings() {
        do {
            try TahoeHostSupport.registerExtension()
            TahoeHostSupport.openExtensionSettings()
            refresh()
            if !extensionEnabled {
                status = "已向系统重新注册 Finder 扩展。请在弹窗或系统设置的 Finder Extensions 中查找，不要去 File Provider。"
            }
        } catch {
            status = error.localizedDescription
        }
    }

    func restartFinder() {
        do {
            try TahoeHostSupport.restartFinder()
            status = "Finder 已重启。"
        } catch {
            status = error.localizedDescription
        }
    }

    private func addManagedFolder(_ url: URL) throws {
        try TahoeManagedRootsStore.addManagedDirectoryURL(url)
    }
}
