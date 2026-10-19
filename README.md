# Musi

A simple SwiftUI music player for iPhone. Add a URL to a remote JSON playlist, choose a song, and play it. Musi supports background audio, lock screen controls, and pull to refresh.

## Playlist

Host a JSON file at a public HTTPS URL. Audio URLs must also use HTTPS. See the [JSON schema](examples/playlist.schema.json) for the full format.

```json
{
  "schema_version": 1,
  "title": "My Music",
  "songs": [
    {
      "title": "First Song",
      "artist": "Artist",
      "url": "https://example.com/audio/first.m4a"
    }
  ]
}
```

Musi also accepts `tracks` or `url_list` instead of `songs`. Entries can be song objects or URL strings. Relative audio URLs are resolved against the playlist URL.

## Run from the command line

Install [Xcode](https://developer.apple.com/xcode/) and [XcodeGen](https://github.com/yonaskolb/XcodeGen). Xcode's graphical interface is not needed for builds.

For a simulator, boot an iPhone simulator and run:

```bash
xcrun simctl list devices available
xcrun simctl boot <simulator-UDID>
./scripts/run-simulator.sh
```

For a physical iPhone, enable Developer Mode, connect and trust the Mac, and sign in under Xcode Settings → Apple Accounts. Find the device UDID and your Team ID, then run:

```bash
xcrun devicectl list devices
./scripts/run-device.sh <device-UDID> <team-ID> com.yourname.musi
```

Keep the same unique bundle ID when updating the app. If iPhone blocks the first launch, trust your developer account in Settings → General → VPN & Device Management, then open Musi again.
