#!/bin/bash
set -euo pipefail

controller="SnapClick/Core/SoftwareVolumeController.swift"
ring_header="SnapClick/Core/AudioRingBuffer.h"
ring_source="SnapClick/Core/AudioRingBuffer.c"
test -f "$controller"
test -f "$ring_header"
test -f "$ring_source"
test ! -f "SnapClick/Core/AtomicFloat.h"
test ! -f "SnapClick/Core/AtomicFloat.c"

for state in notInstalled installing uninstalling disabled starting active recovering failed; do
    rg -q "case .*${state}|case ${state}" "$controller"
done

rg -q 'var isDriverInstalled: Bool' "$controller"
rg -q 'func install\(\)' "$controller"
rg -q 'func uninstall\(\)' "$controller"
rg -q 'restoreAndStop\(\)' "$controller"
rg -q 'AudioHardwareCreateProcessTap' "$controller"
rg -q 'kAudioHardwarePropertyTranslatePIDToProcessObject' "$controller"
rg -q 'AudioHardwareCreateAggregateDevice' "$controller"
rg -q 'AudioDeviceCreateIOProcIDWithBlock' "$controller"
rg -q 'AudioComponentInstanceNew' "$controller"
rg -q 'kAudioUnitSubType_HALOutput' "$controller"
rg -q 'kAudioOutputUnitProperty_CurrentDevice' "$controller"
rg -q 'kAudioUnitProperty_MaximumFramesPerSlice' "$controller"
rg -q 'SCAudioRingBufferWrite' "$controller"
rg -q 'SCAudioRingBufferRead' "$controller"
rg -q 'SCAudioRingBufferGetGain' "$controller"
rg -q 'flags\.pointee\.remove\(\.unitRenderAction_OutputIsSilence\)' "$controller"
rg -q 'atomic_' "$ring_source"
rg -q 'memset' "$ring_source"
xcrun clang -std=c11 "$ring_source" scripts/test_audio_ring_buffer.c -o /tmp/test_audio_ring_buffer
/tmp/test_audio_ring_buffer
rg -q 'SystemAudioDevice\.setDefaultOutput' "$controller"
rg -q 'SystemAudioDevice\.controlOutputID' "$controller"
rg -q 'addOutputControlListener' "$controller"
rg -q 'restorePhysicalOutput' "$controller"
rg -q 'var isActive: Bool' "$controller"
rg -q 'deactivateForSelectedOutput' "$controller"
rg -Uq '(?s)deactivateForSelectedOutput.*forwarder\?\.stop\(\).*defaults\.set\(false, forKey: enabledKey\).*state = \.disabled' "$controller"
if rg -q 'setDefaultInput|defaultInputID|savedInputUID|restoreDefaultInput' "$controller"; then
    echo "software volume must never access the default input device"
    exit 1
fi
if rg -q 'deviceListListener|addDeviceListListener' "$controller"; then
    echo "software volume must not observe its own aggregate-device list changes"
    exit 1
fi

echo "software volume controller contract passed"
