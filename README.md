# Musi

一个简单的 iPhone 流媒体音乐播放器：填写远程歌单 JSON 地址，App 会载入歌曲列表并播放音频。界面使用 SwiftUI 系统组件，支持后台播放、锁屏播放控制、进度拖动和下拉刷新。

## 歌单格式

歌单地址和歌曲地址均需使用 **HTTPS**。App 会在每次打开时读取歌单；在列表上下拉也可以手动刷新。推荐按 [JSON Schema](examples/playlist.schema.json) 维护数据，完整示例在 [examples/playlist.json](examples/playlist.json)：

```json
{
  "schema_version": 1,
  "title": "Musi 演示歌单",
  "songs": [
    { "title": "演示音 A", "artist": "Musi 示例", "url": "https://raw.githubusercontent.com/nano-props/musi/main/examples/audio/demo-a.m4a" },
    { "title": "演示音 B", "artist": "Musi 示例", "url": "https://raw.githubusercontent.com/nano-props/musi/main/examples/audio/demo-b.m4a" }
  ]
}
```

| 字段 | 说明 |
| --- | --- |
| `schema_version` | 格式版本，目前为 `1`。 |
| `title` | 歌单名称，显示在列表标题处。 |
| `songs` | 按播放顺序排列的歌曲数组。 |
| `songs[].title` | 歌曲名称。 |
| `songs[].artist` | 可选的歌手名称。 |
| `songs[].url` | 可直接播放的 HTTPS 音频地址，例如 M4A。 |

将以下演示歌单地址输入 App，就能播放仓库中的两段原创测试音频：

```text
https://raw.githubusercontent.com/nano-props/musi/main/examples/playlist.json
```

在 App 首次打开的设置页，也可以点击“使用演示歌单”，然后点击“保存”。

正式使用时，把自己的 JSON 放在能公开读取的 HTTPS 地址，例如静态文件托管服务，再将真实音频 URL 填入 `songs[].url`。仓库内的两段演示音只是测试素材，可以随时替换。

为方便导入现有歌单，播放器也兼容 `tracks` 或 `url_list` 代替 `songs`，每项可为歌曲对象或 URL 字符串，例如 `{"url_list":["https://example.com/first.m4a"]}`。歌曲对象还可用 `audio_url` 或 `audioUrl`；未提供标题时从文件名生成。相对音频地址会相对于歌单 JSON 地址解析。音频 URL 应直接指向可由 iOS `AVPlayer` 播放的资源；此 App 不解析网页中的播放链接。

## 在终端运行

需要 macOS、完整的 **Xcode**（仅安装 Command Line Tools 不够）、一台 iOS 17 或更高版本的模拟器，以及 [XcodeGen](https://github.com/yonaskolb/XcodeGen)。无需打开 Xcode 图形界面。

```bash
brew install xcodegen
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -runFirstLaunch
xcrun simctl list devices available
xcrun simctl boot <iPhone-模拟器-UDID>
./scripts/run-simulator.sh
```

也可以运行 `xcodegen generate` 生成 `Musi.xcodeproj`，再自行用 `xcodebuild` 构建。

## 安装到自己的 iPhone

1. 用数据线连接 iPhone 与 Mac，在手机上点“信任此电脑”并输入手机密码。在“设置 → 隐私与安全性 → 开发者模式”中打开开发者模式，按提示重启并确认。
2. 第一次真机签名时，在 Xcode 的“设置 → Apple Accounts”登录自己的 Apple 账号。免费账号也能使用 Personal Team 安装到自己的设备；记下这个团队的 Team ID。此后可用终端构建和安装。
3. 运行 `xcrun devicectl list devices`，找到实体 iPhone 的设备 ID。然后执行：

```bash
./scripts/run-device.sh <iPhone-设备ID> <Apple-Team-ID> com.yourname.musi
```

最后一个参数需要换成你自己的唯一 Bundle ID，后续更新 App 时保持不变。脚本会自动生成项目、签名、安装并启动；模拟器默认 ID `com.example.musi` 不会因此改变。免费 Personal Team 的开发描述文件有效期为 7 天，到期后需要重新构建安装。

## 检查歌单解析

这一项只需要 Swift 命令行工具，无需完整 Xcode：

```bash
swiftc Musi/Models/Playlist.swift Tests/PlaylistParserSmoke.swift -o /tmp/musi-playlist-check
/tmp/musi-playlist-check
```

## 图标

图标位于 `Musi/Assets.xcassets/AppIcon.appiconset/AppIcon.png`，为 1024×1024 的不透明 PNG。其设计为深蓝底色与薄荷色音符。
