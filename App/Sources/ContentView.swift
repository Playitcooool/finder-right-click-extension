import SwiftUI

struct ContentView: View {
    @ObservedObject var state: TahoeAppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Tahoe New File")
                .font(.system(size: 28, weight: .semibold))

            Text("当前版本改为官方 Finder Sync 路线，不再尝试全局注入。只有你在宿主 App 里添加过的目录及其子目录，才会在 Finder 空白处右键直接出现“新建文本文件 / Word / Excel / PPT”一级菜单。宿主在启动后会常驻处理创建请求，关窗口不会停止服务。")
                .fixedSize(horizontal: false, vertical: true)

            GroupBox("Extension Status") {
                VStack(alignment: .leading, spacing: 8) {
                    Label(state.extensionEnabled ? "Enabled" : "Disabled", systemImage: state.extensionEnabled ? "checkmark.circle" : "xmark.circle")
                    Label(state.extensionPath, systemImage: "puzzlepiece.extension")
                    Text("启用入口在系统设置的 Finder Extensions。这个扩展不会出现在 File Provider。")
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
            }

            GroupBox("Managed Directories") {
                VStack(alignment: .leading, spacing: 10) {
                    if state.managedPaths.isEmpty {
                        Text("还没有受控目录。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(state.managedPaths, id: \.self) { path in
                            HStack {
                                Text(path)
                                    .font(.system(size: 12, design: .monospaced))
                                    .textSelection(.enabled)
                                Spacer()
                                Button("Remove") {
                                    state.removeFolder(path: path)
                                }
                            }
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                Button("Enable Extension") {
                    state.openExtensionSettings()
                }
                Button("Add Folder") {
                    state.addFolder()
                }
                Button("Clear Folders") {
                    state.clearFolders()
                }
                Button("Restart Finder") {
                    state.restartFinder()
                }
                Button("Refresh") {
                    state.refresh()
                }
            }

            Text(state.status)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 820, minHeight: 420)
    }
}

#Preview {
    ContentView(state: TahoeAppState())
}
