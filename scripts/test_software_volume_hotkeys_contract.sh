#!/bin/bash
set -euo pipefail

hotkeys="SnapClick/Core/HotkeyManager.swift"
controller="SnapClick/Core/SoftwareVolumeController.swift"

rg -q 'tap: \.cghidEventTap' "$hotkeys"
rg -q 'type\.rawValue == 14' "$hotkeys"
rg -q 'NX_KEYTYPE_SOUND_UP' "$controller"
rg -q 'NX_KEYTYPE_SOUND_DOWN' "$controller"
rg -q 'NX_KEYTYPE_MUTE' "$controller"
rg -q '0xA00' "$hotkeys"
rg -q 'handleMediaKey' "$hotkeys"
rg -q 'usesSoftwareGain' "$controller"
rg -q 'SystemAudioDevice\.controlOutputID' "$controller"
rg -q 'return false' "$controller"
rg -q 'softwareVolumeGain' "$controller"
rg -q 'lastNonzeroGain' "$controller"
rg -q 'case.*NX_KEYTYPE_SOUND_UP' "$controller"
rg -q 'case.*NX_KEYTYPE_SOUND_DOWN' "$controller"
rg -q 'case.*NX_KEYTYPE_MUTE' "$controller"

echo "software volume hotkey contract passed"
