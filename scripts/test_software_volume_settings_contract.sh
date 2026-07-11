#!/bin/bash
set -euo pipefail

ui="SnapClick/UI/MainWindow.swift"

rg -q '音频兼容输出' "$ui"
rg -q 'controller\.isSupported' "$ui"
rg -q '需要 macOS 14\.2 或更高版本' "$ui"
rg -q '\.font\(\.system\(size: 12\.5\)\)' "$ui"
rg -q '\.foregroundStyle\(\.secondary\)' "$ui"
rg -q '\.disabled\(isBusy \|\| !controller\.isSupported\)' "$ui"
rg -q '启用' "$ui"
rg -q '停用' "$ui"
rg -q 'controller\.isActive' "$ui"
rg -Uq '(?s)if audioController\.isActive.*audioController\.disable\(\).*else.*audioController\.install\(\)' "$ui"

echo "software volume settings contract passed"
