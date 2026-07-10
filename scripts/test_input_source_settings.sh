#!/usr/bin/env bash
set -euo pipefail

rg -q 'case inputSource\s*= "inputSource"' SnapClick/UI/MainWindow.swift
rg -q 'InputSourceSettingsView\(\)' SnapClick/UI/MainWindow.swift
rg -q 'private let inputSourceController = InputSourceController\.shared' SnapClick/App/AppDelegate.swift
rg -q 'inputSourceController\.start\(\)' SnapClick/App/AppDelegate.swift
rg -q 'inputSourceController\.stop\(\)' SnapClick/App/AppDelegate.swift
rg -q 'ToggleRow\(' SnapClick/UI/InputSourceSettingsView.swift
rg -q 'title: "保留用户选择"\.localized' SnapClick/UI/InputSourceSettingsView.swift
rg -q 'private static let retainSelectionKey = "retainUserInputSourceSelection"' SnapClick/Core/InputSourceController.swift
rg -q 'retainUserSelection = true' SnapClick/Core/InputSourceController.swift
rg -q 'addException\(applicationURL:' SnapClick/UI/InputSourceSettingsView.swift
rg -q 'removeException\(bundleID:' SnapClick/UI/InputSourceSettingsView.swift
rg -q 'TISSelectInputSource' SnapClick/Core/InputSourceController.swift
rg -q 'kTISNotifySelectedKeyboardInputSourceChanged' SnapClick/Core/InputSourceController.swift
rg -q 'addGlobalMonitorForEvents' SnapClick/Core/InputSourceController.swift
rg -q 'removeMonitor' SnapClick/Core/InputSourceController.swift
rg -q 'com\.apple\.TextInputMenuAgent' SnapClick/Core/InputSourceController.swift
rg -q 'AXUIElementCopyElementAtPosition' SnapClick/Core/InputSourceController.swift
