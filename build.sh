#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Clamshell"
DIST="dist"
APP="$DIST/$APP_NAME.app"

echo "==> 编译 (release, arm64)"
# --disable-sandbox：SwiftPM 编译 manifest 时会再套一层 sandbox-exec，
# 在本身已受限的环境里会报 sandbox_apply 失败。
swift build -c release --arch arm64 --disable-sandbox

BIN="$(swift build -c release --arch arm64 --disable-sandbox --show-bin-path)/$APP_NAME"
if [ ! -f "$BIN" ]; then
  echo "构建产物不存在: $BIN" >&2
  exit 1
fi

echo "==> 组装 App Bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"

if [ -f Resources/AppIcon.icns ]; then
  cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

echo "==> 代码签名 (ad-hoc)"
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --verbose=2 "$APP" 2>&1 | sed 's/^/    /'

echo "==> 完成: $APP"
du -sh "$APP"
