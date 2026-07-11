#!/bin/bash
set -euo pipefail

source_file="SnapClick/Core/InputSourceController.swift"

rg -q 'struct RestartableInputMethod' "$source_file"
rg -q 'currentRestartableInputMethod' "$source_file"
rg -q 'isRestartingInputMethod' "$source_file"
rg -q 'restartCurrentInputMethod' "$source_file"
rg -q 'kTISPropertyBundleID' "$source_file"
rg -q 'Library/Input Methods' "$source_file"
rg -q 'runningApplications\(' "$source_file"
rg -q 'withBundleIdentifier:' "$source_file"
rg -q 'imklaunchagent' "$source_file"
rg -q 'openApplication\(' "$source_file"

echo "input method restart contract passed"
