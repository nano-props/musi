#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null; then
  echo "请先安装 XcodeGen：brew install xcodegen" >&2
  exit 1
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "请安装完整 Xcode，并用 xcode-select 选择它。" >&2
  exit 1
fi

device_udid="$(xcrun simctl list devices booted | sed -nE 's/.*\(([0-9A-Fa-f-]{36})\) \(Booted\).*/\1/p' | head -n 1)"
if [[ -z "$device_udid" ]]; then
  echo "请先启动一台 iPhone 模拟器：xcrun simctl list devices available；xcrun simctl boot <设备 UDID>" >&2
  exit 1
fi

xcrun simctl bootstatus "$device_udid" -b
xcodegen generate
xcodebuild \
  -project Musi.xcodeproj \
  -scheme Musi \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$device_udid" \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
xcrun simctl install "$device_udid" build/DerivedData/Build/Products/Debug-iphonesimulator/Musi.app
xcrun simctl launch "$device_udid" com.example.musi

developer_dir="$(xcode-select -p)"
if [[ -d "$developer_dir/Applications/DeviceHub.app" ]]; then
  open -a "$developer_dir/Applications/DeviceHub.app"
elif [[ -d "$developer_dir/Applications/Simulator.app" ]]; then
  open -a "$developer_dir/Applications/Simulator.app"
fi
