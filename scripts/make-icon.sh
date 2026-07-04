#!/bin/sh
# Regenerates MDness/AppIcon.icns from scripts/make-icon.swift.
set -eu
cd "$(dirname "$0")/.."

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

swift scripts/make-icon.swift "$TMP/icon_1024.png"

ICONSET="$TMP/AppIcon.iconset"
mkdir "$ICONSET"
for SIZE in 16 32 128 256 512; do
    sips -z "$SIZE" "$SIZE" "$TMP/icon_1024.png" --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
    DOUBLE=$((SIZE * 2))
    sips -z "$DOUBLE" "$DOUBLE" "$TMP/icon_1024.png" --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o MDness/AppIcon.icns
echo "Created MDness/AppIcon.icns"
