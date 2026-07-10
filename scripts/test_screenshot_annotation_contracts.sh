#!/usr/bin/env bash
set -euo pipefail

rg -q 'case \.arrow:     return "arrow.up.right"' SnapClick/Modules/Screenshot/AnnotationTool.swift
rg -q 'dictionary\(forKey: "annotationToolSizes"\)' SnapClick/Modules/Screenshot/AnnotationCanvas.swift
rg -q 'UserDefaults.standard.set\(' SnapClick/Modules/Screenshot/AnnotationCanvas.swift
rg -q 'private func exportImage\(applyingOutputEffects: Bool = true\)' SnapClick/Modules/Screenshot/AnnotationEditorWindow.swift
rg -q 'ScreenCaptureEngine.shared.applyScreenshotEffects\(to: image\)' SnapClick/Modules/Screenshot/AnnotationEditorWindow.swift
! rg -q 'visiblePixelBounds\(in' SnapClick/Modules/Screenshot/ScreenCaptureEngine.swift
! rg -q 'tiffRepresentation' SnapClick/Modules/Screenshot/ScreenCaptureEngine.swift
rg -Fq 'NSBitmapImageRep(cgImage: cgImage)' SnapClick/Modules/Screenshot/ScreenCaptureEngine.swift
rg -Fq 'sharedScreenshotCIContext' SnapClick/Modules/Screenshot/ScreenCaptureEngine.swift
rg -Fq 'reducedContrastImageCache' SnapClick/Modules/Screenshot/AnnotationCanvas.swift
rg -Fq 'cachedReducedContrastImage()' SnapClick/Modules/Screenshot/AnnotationCanvas.swift
rg -Fq 'ctx.strokePath()' SnapClick/Modules/Screenshot/ScreenCaptureEngine.swift
rg -Fq 'title: "添加圆角".localized' SnapClick/UI/MainWindow.swift
rg -q 'windowCaptureRect\(for win: SCWindow\)' SnapClick/Modules/Screenshot/CaptureOverlayWindow.swift
rg -q 'ScreenCaptureEngine.shared.captureSingleWindow\(win\)' SnapClick/Modules/Screenshot/CaptureOverlayWindow.swift
rg -q 'nextAnnotationBaseImage' SnapClick/Modules/Screenshot/CaptureOverlayWindow.swift
rg -q 'windowCaptureRect\(for win: SCWindow, imageSize: NSSize\)' SnapClick/Modules/Screenshot/CaptureOverlayWindow.swift
rg -q 'winToViewRect\(win\)\.insetBy\(dx: -28, dy: -28\)' SnapClick/Modules/Screenshot/CaptureOverlayWindow.swift
! rg -q 'let winRect = winToViewRect\(win\)\.intersection\(bounds\)' SnapClick/Modules/Screenshot/CaptureOverlayWindow.swift
