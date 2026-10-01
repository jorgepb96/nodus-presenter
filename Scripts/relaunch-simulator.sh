#!/bin/sh
set -eu

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <simulator UUID> <NodusPresenter.app path> [launch arguments...]" >&2
    exit 1
fi

presenter_device=$1
presenter_app=$2
shift 2
presenter_bundle=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$presenter_app/Info.plist")
presenter_icon=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName' "$presenter_app/Info.plist")
if [ "$presenter_bundle" != 'com.nodusresearch.presenter' ] || [ "$presenter_icon" != 'AppIcon' ] || [ ! -s "$presenter_app/Assets.car" ]; then
    echo 'Expected the Nodus Presenter application with its compiled AppIcon.' >&2
    exit 1
fi

# Xcode leaves this separate, iconless test runner on the home screen after UI tests.
presenter_runner='com.nodusresearch.presenter.uitests.xctrunner'
if xcrun simctl get_app_container "$presenter_device" "$presenter_runner" app >/dev/null 2>&1; then
    xcrun simctl uninstall "$presenter_device" "$presenter_runner"
fi
xcrun simctl install "$presenter_device" "$presenter_app"
xcrun simctl terminate "$presenter_device" "$presenter_bundle" >/dev/null 2>&1 || true
xcrun simctl launch "$presenter_device" "$presenter_bundle" "$@"
open -a Simulator --args -CurrentDeviceUDID "$presenter_device"
