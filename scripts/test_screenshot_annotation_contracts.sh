#!/usr/bin/env bash
set -euo pipefail

rg -q 'case \.arrow:     return "arrow.up.right"' SnapClick/Modules/Screenshot/AnnotationTool.swift
rg -q 'dictionary\(forKey: "annotationToolSizes"\)' SnapClick/Modules/Screenshot/AnnotationCanvas.swift
rg -q 'UserDefaults.standard.set\(' SnapClick/Modules/Screenshot/AnnotationCanvas.swift
rg -q 'private func exportImage\(applyingOutputEffects: Bool = true\)' SnapClick/Modules/Screenshot/AnnotationEditorWindow.swift
rg -q 'ScreenCaptureEngine.shared.applyScreenshotEffects\(to: image\)' SnapClick/Modules/Screenshot/AnnotationEditorWindow.swift
rg -q 'ctx.addPath\(CGPath\(roundedRect: drawRect' SnapClick/Modules/Screenshot/ScreenCaptureEngine.swift
rg -q 'private func visiblePixelBounds\(in cg: CGImage\)' SnapClick/Modules/Screenshot/ScreenCaptureEngine.swift
rg -q 'visiblePixelBounds\(in: cg\)' SnapClick/Modules/Screenshot/ScreenCaptureEngine.swift
rg -q 'ctx.setShadow\(offset: \.zero, blur: 0, color: nil\)' SnapClick/Modules/Screenshot/ScreenCaptureEngine.swift
rg -q 'windowCaptureRect\(for win: SCWindow\)' SnapClick/Modules/Screenshot/CaptureOverlayWindow.swift
rg -q 'ScreenCaptureEngine.shared.captureSingleWindow\(win\)' SnapClick/Modules/Screenshot/CaptureOverlayWindow.swift
rg -q 'nextAnnotationBaseImage' SnapClick/Modules/Screenshot/CaptureOverlayWindow.swift
rg -q 'windowCaptureRect\(for win: SCWindow, imageSize: NSSize\)' SnapClick/Modules/Screenshot/CaptureOverlayWindow.swift
rg -q 'winToViewRect\(win\)\.insetBy\(dx: -28, dy: -28\)' SnapClick/Modules/Screenshot/CaptureOverlayWindow.swift
! rg -q 'let winRect = winToViewRect\(win\)\.intersection\(bounds\)' SnapClick/Modules/Screenshot/CaptureOverlayWindow.swift
