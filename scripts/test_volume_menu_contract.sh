#!/bin/bash
set -euo pipefail

menu="SnapClick/UI/StatusBarController.swift"
settings="SnapClick/UI/MainWindow.swift"
view="SnapClick/UI/VolumeMenuItemView.swift"

test -f "$view"
if rg -q 'VolumeMenuItemView|volumeItem\.view' "$menu"; then
    echo "status menu fallback volume slider should be hidden" >&2
    exit 1
fi
rg -q 'Slider\(value:' "$view"
rg -q 'SoftwareVolumeController\.shared' "$view"
rg -q 'speaker\.wave' "$view"
rg -q 'controller\.setGain' "$view"

rg -q 'SoftwareVolumeController\.shared' "$settings"
rg -q '音频兼容输出' "$settings"
rg -q 'isDriverInstalled' "$settings"
rg -q '\.install\(\)' "$settings"
rg -q '\.uninstall\(\)' "$settings"
rg -q '"已启用"' "$settings"
rg -q '"未启用"' "$settings"
rg -q '"启用"' "$settings"
rg -q '"停用"' "$settings"
rg -q '需要 macOS 14\.2 或更高版本' "$settings"

echo "software volume settings contract passed"
