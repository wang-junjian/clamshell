#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> 生成 1024 主图"
mkdir -p build
swift Tools/makeicon.swift build/icon-1024.png

ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

for spec in "16:icon_16x16" "32:icon_16x16@2x" "32:icon_32x32" "64:icon_32x32@2x" \
            "128:icon_128x128" "256:icon_128x128@2x" "256:icon_256x256" "512:icon_256x256@2x" \
            "512:icon_512x512"; do
  size="${spec%%:*}"
  name="${spec##*:}"
  sips -z "$size" "$size" build/icon-1024.png --out "$ICONSET/$name.png" >/dev/null
done

cp build/icon-1024.png "$ICONSET/icon_512x512@2x.png"

echo "==> 打包 icns"
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns

echo "==> 完成: Resources/AppIcon.icns"
ls -la Resources/AppIcon.icns
