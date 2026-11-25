#!/bin/zsh
set -e
cd "$(dirname "$0")"
swift build -c release
APP=VolumeBoost.app
rm -rf $APP && mkdir -p $APP/Contents/MacOS
cp .build/release/VolumeBoost $APP/Contents/MacOS/
cat > $APP/Contents/Info.plist <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>VolumeBoost</string>
<key>CFBundleIdentifier</key><string>local.volumeboost</string>
<key>CFBundleName</key><string>VolumeBoost</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSMinimumSystemVersion</key><string>14.2</string>
<key>NSAudioCaptureUsageDescription</key><string>VolumeBoost needs to hear your Mac's sound so it can make it louder.</string>
</dict></plist>
PL
codesign --force --sign - $APP
echo "Built $PWD/$APP"
