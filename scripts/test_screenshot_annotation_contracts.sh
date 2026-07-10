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
rg -Fq 'struct WindowCaptureResult' SnapClick/Modules/Screenshot/ScreenCaptureEngine.swift
rg -Fq 'includesSystemFrame: includeSystemFrame' SnapClick/Modules/Screenshot/ScreenCaptureEngine.swift
rg -Fq 'includesSystemFrame: false' SnapClick/Modules/Screenshot/ScreenCaptureEngine.swift
rg -Fq '[.bestResolution]' SnapClick/Modules/Screenshot/ScreenCaptureEngine.swift
rg -Fq 'requestedSystemFrame ?? ScreenshotSettings.shared.enableShadow' SnapClick/Modules/Screenshot/ScreenCaptureEngine.swift
rg -Fq 'includeSystemFrame ? [.bestResolution] : [.boundsIgnoreFraming, .bestResolution]' SnapClick/Modules/Screenshot/ScreenCaptureEngine.swift
rg -Fq 'annotationBaseIncludesSystemFrame' SnapClick/Modules/Screenshot/CaptureOverlayWindow.swift
rg -Fq 'applyingOutputEffects && !annotationBaseIncludesSystemFrame' SnapClick/Modules/Screenshot/CaptureOverlayWindow.swift
rg -Fq 'capture.includesSystemFrame' SnapClick/Modules/Screenshot/CaptureOverlayWindow.swift
rg -Fq 'captureSingleWindow(win, includeSystemFrame: false)' SnapClick/Modules/Recording/RecordSelectionOverlayWindow.swift
rg -Fq 'selectedWindowImage = img.image' SnapClick/Modules/Recording/RecordSelectionOverlayWindow.swift
if rg -Fq 'NSEvent.isMouseCoalescingEnabled' SnapClick/Modules/Screenshot/AnnotationCanvas.swift; then
    exit 1
fi
rg -Fq 'title: "添加圆角".localized' SnapClick/UI/MainWindow.swift
rg -Fq 'static let cornerRadius: CGFloat = 12' SnapClick/Modules/Screenshot/AnnotationTool.swift
rg -Fq 'static let buttonCornerRadius: CGFloat = 7' SnapClick/Modules/Screenshot/AnnotationTool.swift
rg -Fq 'static func makeView() -> NSView' SnapClick/Modules/Screenshot/AnnotationTool.swift
rg -Fq 'static func contentHost(for toolbar: NSView) -> NSView' SnapClick/Modules/Screenshot/AnnotationTool.swift
rg -Fq 'NSGlassEffectView()' SnapClick/Modules/Screenshot/AnnotationTool.swift
rg -Fq 'NSVisualEffectView()' SnapClick/Modules/Screenshot/AnnotationTool.swift
rg -Fq 'case .pen:       return "pencil.tip"' SnapClick/Modules/Screenshot/AnnotationTool.swift
rg -Fq 'case .highlight: return "rectangle.dashed"' SnapClick/Modules/Screenshot/AnnotationTool.swift
rg -Fq 'case .mosaic:    return "square.grid.3x3.fill"' SnapClick/Modules/Screenshot/AnnotationTool.swift
rg -Fq 'editorToolbar = AnnotationToolbarChrome.makeView()' SnapClick/Modules/Screenshot/AnnotationEditorWindow.swift
rg -Fq 'let toolbar = AnnotationToolbarChrome.makeView()' SnapClick/Modules/Screenshot/CaptureOverlayWindow.swift
rg -q 'windowCaptureRect\(for win: SCWindow\)' SnapClick/Modules/Screenshot/CaptureOverlayWindow.swift
rg -q 'ScreenCaptureEngine.shared.captureSingleWindow\(win\)' SnapClick/Modules/Screenshot/CaptureOverlayWindow.swift
rg -q 'nextAnnotationBaseImage' SnapClick/Modules/Screenshot/CaptureOverlayWindow.swift
rg -q 'windowCaptureRect\(for win: SCWindow, imageSize: NSSize\)' SnapClick/Modules/Screenshot/CaptureOverlayWindow.swift
rg -q 'winToViewRect\(win\)\.insetBy\(dx: -28, dy: -28\)' SnapClick/Modules/Screenshot/CaptureOverlayWindow.swift
! rg -q 'let winRect = winToViewRect\(win\)\.intersection\(bounds\)' SnapClick/Modules/Screenshot/CaptureOverlayWindow.swift
