#!/bin/sh
# Builds MDness (Release) and packages it into a drag-to-Applications DMG at
# dist/MDness-<version>.dmg.
set -eu
cd "$(dirname "$0")/.."

xcodebuild -project MDness.xcodeproj -scheme MDness -configuration Release \
    -derivedDataPath build -destination 'platform=macOS' build

APP=build/Build/Products/Release/MDness.app
VERSION=$(defaults read "$PWD/$APP/Contents/Info" CFBundleShortVersionString)
STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT

cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

mkdir -p dist
hdiutil create -volname "MDness" -srcfolder "$STAGING" -ov -format UDZO \
    "dist/MDness-$VERSION.dmg"
echo "Created dist/MDness-$VERSION.dmg"
