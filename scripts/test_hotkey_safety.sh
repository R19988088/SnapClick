#!/usr/bin/env bash
set -euo pipefail

rg -q 'keyboardEventAutorepeat' SnapClick/Core/HotkeyManager.swift
rg -Fq 'private func handleKeyEvent(keyCode: CGKeyCode, flags: CGEventFlags) -> Bool' SnapClick/Core/HotkeyManager.swift
rg -Fq 'let handled = HotkeyManager.shared.handleKeyEvent' SnapClick/Core/HotkeyManager.swift
rg -Fq 'if handled {' SnapClick/Core/HotkeyManager.swift
rg -q 'timeIntervalSince\(lastShiftDown\) < 0\.25' SnapClick/App/AppDelegate.swift
rg -q 'lastShiftDown = Date\.distantPast' SnapClick/App/AppDelegate.swift
rg -q '\.onDisappear \{ stopRecording\(\) \}' SnapClick/UI/MainWindow.swift
