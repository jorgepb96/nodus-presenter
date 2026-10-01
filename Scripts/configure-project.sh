#!/bin/sh
set -eu
# Compile the documented hinge APIs only with an SDK which declares them.
sdk_version=$(xcrun --sdk iphoneos --show-sdk-version)
xcodegen generate
if awk -v v="$sdk_version" 'BEGIN {split(v,a,"."); exit !(a[1]>27 || (a[1]==27 && a[2]>=1))}'; then
    sed -i '' 's/SWIFT_VERSION = 5.0;/SWIFT_VERSION = 5.0; SWIFT_ACTIVE_COMPILATION_CONDITIONS = "$(inherited) NODUS_FOLDABLE_SDK";/' NodusPresenter.xcodeproj/project.pbxproj
fi
