#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build dist
APP="build/Nova Prism.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
for ARCH in arm64 x86_64; do
  xcrun swiftc -swift-version 5 -parse-as-library -O -target "${ARCH}-apple-macos13.0" -sdk "$(xcrun --sdk macosx --show-sdk-path)" Sources/NovaPrism.swift -o "build/prism-${ARCH}"
done
lipo -create build/prism-arm64 build/prism-x86_64 -output "$APP/Contents/MacOS/NovaPrism"
cp Info.plist "$APP/Contents/Info.plist"
cp Resources/Nebulosa.png Resources/Languages.json "$APP/Contents/Resources/"
python3 scripts/service.py "$APP/Contents/Resources"
codesign --force --deep --sign - "$APP"
"$APP/Contents/MacOS/NovaPrism" --self-test
mkdir -p build/dmg
ditto "$APP" "build/dmg/Nova Prism.app"
ln -s /Applications build/dmg/Applications
cp README.txt build/dmg/LEGGIMI-README.txt
hdiutil create -volname "Nova Prism 3.0" -srcfolder build/dmg -ov -format UDZO dist/NovaPrism-3.0.0-macOS-universal.dmg
ditto -c -k --keepParent "$APP" dist/NovaPrism-3.0.0-macOS-universal.zip
shasum -a 256 dist/*.dmg dist/*.zip > dist/SHA256SUMS-macOS.txt
