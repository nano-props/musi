# Musi

一个简单的 iPhone 流媒体音乐播放器：填写远程歌单 JSON 地址，App 会载入歌曲列表并播放音频。界面使用 SwiftUI 系统组件，支持后台播放、锁屏播放控制、进度拖动和下拉刷新。

## 歌单格式

歌单地址和歌曲地址均需使用 **HTTPS**。App 会在每次打开时读取歌单；在列表上下拉也可以手动刷新。服务端应返回 JSON，例如 [examples/playlist.json](examples/playlist.json)：

```json
{
  "title": "我的歌单",
  "songs": [
    { "title": "第一首歌", "artist": "示例歌手", "url": "https://example.com/audio/first.m4a" },
    { "title": "第二首歌", "url": "https://example.com/audio/second.m4a" }
  ]
}
```

也支持 `tracks` 或 `url_list` 代替 `songs`，每项可以是歌曲对象或 URL 字符串。例如 `{"url_list":["https://example.com/first.m4a"]}`。歌曲对象可用 `url`、`audio_url` 或 `audioUrl`；`title`、`artist` 可选。相对音频地址会相对于歌单 JSON 地址解析。音频 URL 应直接指向可由 iOS `AVPlayer` 播放的资源，例如 M4A；此 App 不解析网页中的播放链接。

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

也可以运行 `xcodegen generate` 生成 `Musi.xcodeproj`，再自行用 `xcodebuild` 构建。真机安装需要在 `project.yml` 中将 `PRODUCT_BUNDLE_IDENTIFIER` 改为自己的唯一 ID，并配置 Apple 开发团队和签名。这个示例项目默认使用 `com.example.musi`，仅便于模拟器开发。

## 检查歌单解析

这一项只需要 Swift 命令行工具，无需完整 Xcode：

```bash
swiftc Musi/Models/Playlist.swift Tests/PlaylistParserSmoke.swift -o /tmp/musi-playlist-check
/tmp/musi-playlist-check
```

## 图标

图标位于 `Musi/Assets.xcassets/AppIcon.appiconset/AppIcon.png`，为 1024×1024 的不透明 PNG。其设计为深蓝底色与薄荷色音符。
