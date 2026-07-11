#!/bin/bash
set -euo pipefail

ui="SnapClick/UI/MainWindow.swift"
localization="SnapClick/Core/AppSettings.swift"

rg -q 'InputMethodRestartRow' "$ui"
rg -q 'currentRestartableInputMethod' "$ui"
rg -q 'restartCurrentInputMethod' "$ui"
rg -q 'isRestartingInputMethod' "$ui"
rg -q '重启输入法' "$ui"
rg -q '"重启输入法"' "$localization"
rg -q '"当前输入法"' "$localization"

echo "input method restart UI contract passed"
