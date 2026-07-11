#!/bin/bash
set -euo pipefail

controller="SnapClick/Core/SoftwareVolumeController.swift"
app_plist="SnapClick/App/Info.plist"
project="SnapClick.xcodeproj/project.pbxproj"
driver="SnapClickAudioDriver/Driver.cpp"
plist="SnapClickAudioDriver/Info.plist"

test -f "$driver"
test -f "$plist"
test -x scripts/build_audio_driver.sh
test -d ThirdParty/libASPL
rg -q 'com\.snapclick\.audio\.control' "$driver"
rg -q 'Direction = aspl::Direction::Output' "$driver"
rg -q 'AddStreamWithControlsAsync' "$driver"
if rg -q 'Direction::Input|AddStreamAsync\(input|OnReadClientInput' "$driver"; then
    echo "control driver must not publish an input stream"
    exit 1
fi
rg -q 'CFBundleIdentifier.*com\.snapclick\.audio\.driver|com\.snapclick\.audio\.driver' "$plist"
rg -q 'AudioHardwareCreateProcessTap' "$controller"
rg -q 'CATapDescription' "$controller"
plutil -extract NSAudioCaptureUsageDescription raw "$app_plist" | rg -q '系统音频捕获'
rg -q 'kAudioAggregateDeviceTapListKey' "$controller"
rg -q 'AudioDeviceCreateIOProcIDWithBlock' "$controller"
rg -q 'Build SnapClick Audio Driver' "$project"
rg -q 'SnapClickAudio\.driver' "$project"
rg -q '/Library/Audio/Plug-Ins/HAL/SnapClickAudio\.driver' "$controller"
rg -q 'com\.snapclick\.audio\.driver' "$controller"

echo "output-only audio control driver contract passed"
