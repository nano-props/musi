#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ $# -ne 3 ]]; then
  echo "用法: $0 <iPhone-设备ID> <Apple-Team-ID> <唯一Bundle-ID>" >&2
  echo "示例: $0 00008110-001234567890801E ABCDE12345 com.yourname.musi" >&2
  exit 1
fi

device_id="$1"
team_id="$2"
bundle_id="$3"

if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

if ! command -v xcodegen >/dev/null; then
  echo "请先安装 XcodeGen：brew install xcodegen" >&2
  exit 1
fi

xcodegen generate
xcodebuild \
  -project Musi.xcodeproj \
  -scheme Musi \
  -configuration Debug \
  -destination "platform=iOS,id=$device_id" \
  -derivedDataPath build/DerivedData \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  DEVELOPMENT_TEAM="$team_id" \
  PRODUCT_BUNDLE_IDENTIFIER="$bundle_id" \
  CODE_SIGN_STYLE=Automatic \
  CODE_SIGNING_ALLOWED=YES \
  build

xcrun devicectl device install app \
  --device "$device_id" \
  build/DerivedData/Build/Products/Debug-iphoneos/Musi.app
xcrun devicectl device process launch \
  --device "$device_id" \
  "$bundle_id"
