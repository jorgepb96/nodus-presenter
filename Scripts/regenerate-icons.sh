#!/bin/sh
set -eu
presenter_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
presenter_icon_tmp=$(mktemp -d "${TMPDIR:-/tmp}/nodus-icons.XXXXXX")
trap 'rm -rf "$presenter_icon_tmp"' EXIT
xcrun swiftc "$presenter_root/App/NodusBrand.swift" "$presenter_root/Scripts/generate-icon.swift" -o "$presenter_icon_tmp/generate-icon"
"$presenter_icon_tmp/generate-icon" "$presenter_root/App/Assets.xcassets/AppIcon.appiconset/icon.png"
"$presenter_icon_tmp/generate-icon" "$presenter_root/App/Assets.xcassets/AppIcon.appiconset/icon-dark.png" --dark
cp "$presenter_root/App/Assets.xcassets/AppIcon.appiconset/icon.png" "$presenter_root/App/Assets.xcassets/AppIconPreview.imageset/icon.png"
