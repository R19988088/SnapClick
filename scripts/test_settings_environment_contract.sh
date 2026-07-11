#!/bin/bash
set -euo pipefail

app="SnapClick/App/SnapClickApp.swift"

rg -q 'MainWindow\(\)' "$app"
rg -Uq 'MainWindow\(\)[[:space:]]*\.environmentObject\(ColorPickerEngine\.shared\)[[:space:]]*\.environmentObject\(PinWindowManager\.shared\)' "$app"

echo "Settings environment contract passed."
