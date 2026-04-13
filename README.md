# Tahoe New File

`Tahoe New File` 现在走官方 `Finder Sync` 路线，用来把这 4 个入口放到 Finder 空白处的一级右键菜单：

- `新建文本文件`
- `新建 Word`
- `新建 Excel`
- `新建 PPT`

它不依赖 Quick Actions。限制是：只有你在宿主 App 里添加过的目录，以及这些目录的子目录，才会显示这个右键菜单。

结构分成 2 个产物：

- `TahoeNewFileHost.app`
  宿主 App，负责启用扩展、选择受控目录、以及在目录变更后刷新 Finder。
- `TahoeFinderSync.appex`
  官方 Finder Sync 扩展。它在受控目录的空白处右键时直接提供 4 个一级菜单项，并从扩展 bundle 里的内置模板创建文件。

## Build

1. 先生成工程：

```bash
xcodegen generate
```

2. 用完整 Xcode 构建：

```bash
DEVELOPER_DIR=/Volumes/Samsung/Applications/Xcode.app/Contents/Developer \
xcodebuild -project TahoeNewFile.xcodeproj -alltargets -configuration Debug build
```

3. 构建完成后会得到：

- `TahoeNewFileHost.app`
- `TahoeFinderSync.appex`

## Install

1. 打开 `TahoeNewFileHost.app`
2. 点击 `Enable Extension`，在系统扩展管理界面启用 `Tahoe Finder Sync`
3. 回到宿主 App，点击 `Add Folder`，选择要接管的目录
4. 如有需要点击 `Restart Finder`
5. 在这些目录或它们的子目录里，对空白区域右键，检查 4 个一级菜单项是否已出现

## Template Assets

`.docx` / `.xlsx` / `.pptx` 来自仓库里的内置最小 OOXML 模板。构建后它们会被复制到 Finder Sync 扩展的资源目录。首次克隆后可以重新生成：

```bash
bash Scripts/generate_ooxml_templates.sh
```

## Important Caveats

- 这是官方 Finder Sync 方案，不需要 `lldb` 注入 Finder。
- 它不能覆盖 Finder 里的所有任意目录，只能覆盖你明确添加的受控目录树。
- 宿主 App 和扩展通过当前用户的 `Application Support/TahoeNewFile/managed-roots.plist` 共享受控目录配置。
