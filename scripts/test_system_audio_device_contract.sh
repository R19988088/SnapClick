#!/bin/bash
set -euo pipefail

source_file="SnapClick/Core/SystemAudioDevice.swift"
test -f "$source_file"

rg -q 'static func defaultOutputID\(\)' "$source_file"
rg -q 'static func defaultInputID\(\)' "$source_file"
rg -q 'static func outputDeviceIDs\(\)' "$source_file"
rg -q 'static func inputDeviceIDs\(\)' "$source_file"
rg -q 'static func physicalOutputDeviceIDs\(\)' "$source_file"
rg -q 'static func isBuiltInOutput\(_ deviceID: AudioDeviceID\)' "$source_file"
rg -q 'kAudioDevicePropertyTransportType' "$source_file"
rg -q 'kAudioDeviceTransportTypeVirtual' "$source_file"
rg -q 'kAudioDeviceTransportTypeBuiltIn' "$source_file"
rg -q 'static func uid\(for deviceID: AudioDeviceID\)' "$source_file"
rg -q 'static func setDefaultOutput\(_ deviceID: AudioDeviceID\)' "$source_file"
rg -q 'static func setDefaultInput\(_ deviceID: AudioDeviceID\)' "$source_file"
rg -q 'static func inputDeviceID\(uid: String\)' "$source_file"
rg -q 'static func addDefaultOutputListener' "$source_file"
rg -q 'AudioObjectIsPropertySettable' "$source_file"
rg -q 'controlDeviceUID' "$source_file"
rg -q 'func controlOutputID' "$source_file"
rg -q 'func outputVolume' "$source_file"
rg -q 'func setOutputVolume' "$source_file"
rg -q 'func outputMuted' "$source_file"
rg -q 'func addOutputControlListener' "$source_file"
rg -q 'kAudioHardwarePropertyDefaultSystemOutputDevice' "$source_file"
rg -q 'kAudioHardwarePropertyDevices' "$source_file"
rg -q 'kAudioDevicePropertyDeviceUID' "$source_file"
rg -q 'kAudioHardwarePropertyTranslateUIDToDevice' "$source_file"
rg -q 'static func deviceID\(uid: String\)' "$source_file"
rg -Uq 'static func controlOutputID\(\).*deviceID\(uid: controlDeviceUID\)' "$source_file"
if rg -q 'unsafeBitCast\(0, to: T\.self\)' "$source_file"; then
    echo "scalar properties must not initialize generic values with unsafeBitCast" >&2
    exit 1
fi

echo "system audio device contract passed"
