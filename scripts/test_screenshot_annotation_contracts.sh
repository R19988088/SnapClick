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
rg -Fq '[.bestResolution]' SnapClick/Modules/Screenshot/ScreenCaptureEngine.swift
rg -Fq 'requestedSystemFrame ?? ScreenshotSettings.shared.enableShadow' SnapClick/Modules/Screenshot/ScreenCaptureEngine.swift
rg -Fq 'private func backingScaleFactor(for window: SCWindow)' SnapClick/Modules/Screenshot/ScreenCaptureEngine.swift
rg -Fq 'CGDisplayBounds(displayID).contains(center)' SnapClick/Modules/Screenshot/ScreenCaptureEngine.swift
! rg -Fq 'let scale = NSScreen.main?.backingScaleFactor ?? 2.0' SnapClick/Modules/Screenshot/ScreenCaptureEngine.swift
rg -Fq 'includeSystemFrame ? [.bestResolution] : [.boundsIgnoreFraming, .bestResolution]' SnapClick/Modules/Screenshot/ScreenCaptureEngine.swift
rg -Fq 'cfg.ignoreShadowsDisplay = false' SnapClick/Modules/Screenshot/ScreenCaptureEngine.swift
cg_display_line=$(rg -n 'CGDisplayCreateImage\(displayID\)' SnapClick/Modules/Screenshot/ScreenCaptureEngine.swift | head -1 | cut -d: -f1)
sc_display_line=$(rg -n 'SCShareableContent\.excludingDesktopWindows' SnapClick/Modules/Screenshot/ScreenCaptureEngine.swift | head -1 | cut -d: -f1)
if (( cg_display_line >= sc_display_line )); then
    exit 1
fi
rg -Fq 'let screenshotConfig = SCScreenshotConfiguration()' SnapClick/Modules/Screenshot/ScreenCaptureEngine.swift
rg -Fq 'screenshotConfig.ignoreShadows = !includeSystemFrame' SnapClick/Modules/Screenshot/ScreenCaptureEngine.swift
rg -Fq 'screenshotConfig.includeChildWindows = true' SnapClick/Modules/Screenshot/ScreenCaptureEngine.swift
rg -Fq 'SCScreenshotManager.captureScreenshot(' SnapClick/Modules/Screenshot/ScreenCaptureEngine.swift
rg -Fq 'cfg.ignoreShadowsSingleWindow = !includeSystemFrame' SnapClick/Modules/Screenshot/ScreenCaptureEngine.swift
rg -Fq 'cfg.includeChildWindows = true' SnapClick/Modules/Screenshot/ScreenCaptureEngine.swift
rg -Fq 'annotationBaseIncludesSystemFrame' SnapClick/Modules/Screenshot/CaptureOverlayWindow.swift
rg -Fq 'applyingOutputEffects && !annotationBaseIncludesSystemFrame' SnapClick/Modules/Screenshot/CaptureOverlayWindow.swift
rg -Fq 'capture.includesSystemFrame' SnapClick/Modules/Screenshot/CaptureOverlayWindow.swift
rg -Fq 'captureSingleWindow(win, includeSystemFrame: false)' SnapClick/Modules/Recording/RecordSelectionOverlayWindow.swift
rg -Fq 'selectedWindowImage = img.image' SnapClick/Modules/Recording/RecordSelectionOverlayWindow.swift
rg -Fq '@AppStorage("annotationMaximumPressure")' SnapClick/Core/AppSettings.swift
rg -Fq '@AppStorage("annotationPressureDeadZone")' SnapClick/Core/AppSettings.swift
rg -Fq 'max(0.01, min(storedMaximumPressure, 1))' SnapClick/Core/AppSettings.swift
rg -Fq 'max(0, min(storedDeadZone, 0.3))' SnapClick/Core/AppSettings.swift
! rg -Fq 'var annotationPressureAmplification:' SnapClick/Core/AppSettings.swift
rg -Fq 'SectionLabel(title: "笔模式优化".localized' SnapClick/UI/MainWindow.swift
rg -Fq 'Text("设备最大压力".localized)' SnapClick/UI/MainWindow.swift
rg -Fq 'Slider(value: $settings.annotationMaximumPressure, in: 0.01...1, step: 0.01)' SnapClick/UI/MainWindow.swift
rg -Fq '$settings.annotationPressureDeadZone' SnapClick/UI/MainWindow.swift
rg -Fq 'CardDivider()' SnapClick/UI/MainWindow.swift
pressure_section_line=$(rg -n 'SectionLabel\(title: "笔模式优化"\.localized' SnapClick/UI/MainWindow.swift | cut -d: -f1)
storage_section_line=$(rg -n 'SectionLabel\(title: "储存设置"\.localized' SnapClick/UI/MainWindow.swift | cut -d: -f1)
if (( pressure_section_line >= storage_section_line )); then exit 1; fi
rg -Fq 'previousMouseCoalescingEnabled = NSEvent.isMouseCoalescingEnabled' SnapClick/Modules/Screenshot/AnnotationCanvas.swift
rg -Fq 'NSEvent.isMouseCoalescingEnabled = false' SnapClick/Modules/Screenshot/AnnotationCanvas.swift
rg -Fq 'NSEvent.isMouseCoalescingEnabled = previousMouseCoalescingEnabled' SnapClick/Modules/Screenshot/AnnotationCanvas.swift
rg -Fq 'NSApplication.didResignActiveNotification' SnapClick/Modules/Screenshot/AnnotationCanvas.swift
rg -Fq 'NSWindow.didResignKeyNotification' SnapClick/Modules/Screenshot/AnnotationCanvas.swift
rg -Fq 'cancelActivePenInput' SnapClick/Modules/Screenshot/AnnotationCanvas.swift
rg -Fq 'inputStabilizer.begin(' SnapClick/Modules/Screenshot/AnnotationCanvas.swift
rg -Fq 'inputStabilizer.append(' SnapClick/Modules/Screenshot/AnnotationCanvas.swift
rg -Fq 'inputStabilizer.finish(' SnapClick/Modules/Screenshot/AnnotationCanvas.swift
if rg -Fq 'AnnotationPressureCurveLUT' SnapClick/Modules/Screenshot/AnnotationInputStabilizer.swift; then exit 1; fi
if rg -Fq 'PreparedPressureCurve' SnapClick/Modules/Screenshot/AnnotationInputStabilizer.swift; then exit 1; fi
if rg -Fq '109.58946814903847' SnapClick/Modules/Screenshot/AnnotationInputStabilizer.swift; then exit 1; fi
if rg -q '//' SnapClick/Modules/Screenshot/AnnotationInputStabilizer.swift; then exit 1; fi
if rg -Fq '/// 标注画笔达到完整压力时对应的设备输入上限' SnapClick/Core/AppSettings.swift; then exit 1; fi
if rg -Fq '/// 标注画笔数位板压力死区' SnapClick/Core/AppSettings.swift; then exit 1; fi
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
