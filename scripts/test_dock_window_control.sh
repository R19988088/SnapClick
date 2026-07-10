#!/usr/bin/env bash
set -euo pipefail

rg -q 'dockWindowControlEnabled' SnapClick/Core/AppSettings.swift
rg -q 'Dock 窗口控制' SnapClick/UI/MainWindow.swift
rg -q 'FinderDockPreviewController' SnapClick/App/AppDelegate.swift
rg -q 'private enum PreviewMetrics' SnapClick/App/AppDelegate.swift
rg -q 'tileWidth: CGFloat = 179' SnapClick/App/AppDelegate.swift
rg -q 'imageHeight: CGFloat = 147' SnapClick/App/AppDelegate.swift
rg -q 'override var intrinsicContentSize: NSSize' SnapClick/App/AppDelegate.swift
rg -q 'widthConstraint = widthAnchor.constraint\(equalToConstant: PreviewMetrics.tileWidth\)' SnapClick/App/AppDelegate.swift
rg -q 'heightAnchor.constraint\(equalToConstant: PreviewMetrics.tileHeight\).isActive = true' SnapClick/App/AppDelegate.swift
rg -q 'NSGlassEffectView' SnapClick/App/AppDelegate.swift
rg -q 'NSGlassEffectContainerView' SnapClick/App/AppDelegate.swift
! rg -q 'glassView.contentView = contentView' SnapClick/App/AppDelegate.swift
rg -q 'NSClassFromString\("NSGlassEffectView"\)' SnapClick/App/AppDelegate.swift
rg -q 'NSClassFromString\("NSGlassEffectContainerView"\)' SnapClick/App/AppDelegate.swift
rg -q 'glassView.setValue\(scrollView, forKey: "contentView"\)' SnapClick/App/AppDelegate.swift
rg -q 'container.setValue\(glassView, forKey: "contentView"\)' SnapClick/App/AppDelegate.swift
rg -q 'NSVisualEffectView' SnapClick/App/AppDelegate.swift
rg -q 'tileCornerRadius: CGFloat = 16' SnapClick/App/AppDelegate.swift
rg -q 'imageCornerRadius: CGFloat = 14' SnapClick/App/AppDelegate.swift
rg -q 'panelCornerRadius: CGFloat = 22' SnapClick/App/AppDelegate.swift
rg -q 'pointerSize: CGFloat = 12' SnapClick/App/AppDelegate.swift
rg -q 'cornerCurve = \.continuous' SnapClick/App/AppDelegate.swift
! rg -q 'layer\?\.borderWidth = 1' SnapClick/App/AppDelegate.swift
rg -q 'private final class ThumbnailView' SnapClick/App/AppDelegate.swift
rg -q 'aspectFitRect\(imageSize:' SnapClick/App/AppDelegate.swift
rg -q 'shadowBlurRadius = 8' SnapClick/App/AppDelegate.swift
rg -q 'shadowOffset = NSSize\(width: 0, height: -3\)' SnapClick/App/AppDelegate.swift
rg -q 'black.withAlphaComponent\(0.18\)' SnapClick/App/AppDelegate.swift
rg -q 'border.lineWidth = 1' SnapClick/App/AppDelegate.swift
rg -q 'black.withAlphaComponent\(0.3\)' SnapClick/App/AppDelegate.swift
rg -q 'NSColor.controlAccentColor.cgColor' SnapClick/App/AppDelegate.swift
rg -q 'accentView.alphaValue = 0.9' SnapClick/App/AppDelegate.swift
rg -q 'closeButton' SnapClick/App/AppDelegate.swift
rg -q 'private final class CloseButton' SnapClick/App/AppDelegate.swift
! rg -q 'closeButtonSize' SnapClick/App/AppDelegate.swift
rg -q 'NSColor.white.setFill\(\)' SnapClick/App/AppDelegate.swift
rg -q 'NSColor.darkGray.setStroke\(\)' SnapClick/App/AppDelegate.swift
rg -q 'NSColor.black.withAlphaComponent\(0.24\).setStroke\(\)' SnapClick/App/AppDelegate.swift
rg -q 'shadowBlurRadius = 4' SnapClick/App/AppDelegate.swift
rg -q 'closeButton.alphaValue = 0' SnapClick/App/AppDelegate.swift
rg -q 'closeButton.alphaValue = 1' SnapClick/App/AppDelegate.swift
rg -q 'func collapse\(completion:' SnapClick/App/AppDelegate.swift
rg -q 'shrinkPreviewPanelAfterTileClose' SnapClick/App/AppDelegate.swift
! rg -q 'panelHeight\(near dockApp: DockApp\)' SnapClick/App/AppDelegate.swift
! rg -q 'dockApp.bounds.height \+ 10' SnapClick/App/AppDelegate.swift
! rg -q 'effectView.alphaValue = 0.7' SnapClick/App/AppDelegate.swift
! rg -q 'setFrame\(centeredFrame\(width:' SnapClick/App/AppDelegate.swift
rg -q 'layer\?\.masksToBounds = false' SnapClick/App/AppDelegate.swift
! rg -q 'private func close\(_ preview: DockWindowPreview\).*hidePreview' SnapClick/App/AppDelegate.swift
! rg -q 'imageView.layer\?\.borderWidth = 2' SnapClick/App/AppDelegate.swift
rg -q 'NSTrackingArea' SnapClick/App/AppDelegate.swift
rg -q 'imageView.image = preview.image$' SnapClick/App/AppDelegate.swift
! rg -q 'imageView.image = preview.image \\?\\? preview.app.icon' SnapClick/App/AppDelegate.swift
rg -q 'dockApp\(atAXPoint point: CGPoint\)' SnapClick/App/AppDelegate.swift
rg -q 'AXUIElementCopyElementAtPosition' SnapClick/App/AppDelegate.swift
rg -q 'copyWindows\(for app: NSRunningApplication\)' SnapClick/App/AppDelegate.swift
rg -q 'copyCGWindows\(for app: NSRunningApplication\)' SnapClick/App/AppDelegate.swift
rg -q 'ownerNameMatches\(item: item, names: ownerNames\)' SnapClick/App/AppDelegate.swift
rg -q 'windowOwnerNames\(for app: NSRunningApplication\)' SnapClick/App/AppDelegate.swift
rg -q 'private struct AXWindowInfo' SnapClick/App/AppDelegate.swift
rg -q 'validAXWindows\(for pid: pid_t\)' SnapClick/App/AppDelegate.swift
rg -q 'previewForCGWindow\(' SnapClick/App/AppDelegate.swift
rg -q 'matchAXWindow\(windowID: CGWindowID, bounds: CGRect, in axWindows: \[AXWindowInfo\]\)' SnapClick/App/AppDelegate.swift
rg -q 'previewFingerprint\(for previews: \[DockWindowPreview\]\)' SnapClick/App/AppDelegate.swift
rg -q 'lastPreviewFingerprint' SnapClick/App/AppDelegate.swift
rg -q 'panelWidth = min\(contentWidth, visibleFrame' SnapClick/App/AppDelegate.swift
! rg -q 'max\(340, visibleFrame\(near: dockApp.bounds\)\.width - 24\)' SnapClick/App/AppDelegate.swift
rg -q 'PermissionManager.shared.requestScreenRecordingPermission\(\)' SnapClick/App/AppDelegate.swift
rg -q 'import ScreenCaptureKit' SnapClick/App/AppDelegate.swift
rg -q 'loadThumbnails\(' SnapClick/App/AppDelegate.swift
rg -q 'SCShareableContent.current' SnapClick/App/AppDelegate.swift
rg -q 'SCScreenshotManager.captureImage' SnapClick/App/AppDelegate.swift
rg -q 'SCContentFilter\(desktopIndependentWindow: screenCaptureWindow\)' SnapClick/App/AppDelegate.swift
rg -q 'NSImage\(cgImage: image, size: targetSize\)' SnapClick/App/AppDelegate.swift
! rg -q 'CGSHWCaptureWindowList' SnapClick/App/AppDelegate.swift
! rg -q 'CGWindowListCreateImage\(.null, \\.optionIncludingWindow' SnapClick/App/AppDelegate.swift
rg -q 'kCGWindowSharingState' SnapClick/App/AppDelegate.swift
rg -q 'validAXWindows.isEmpty' SnapClick/App/AppDelegate.swift
rg -q 'isUsableCGWindowFallback\(title: title, bounds: bounds, onScreen: onScreen\)' SnapClick/App/AppDelegate.swift
! rg -q 'if !validAXWindows\.isEmpty && matchedAXWindow == nil \{ return nil \}' SnapClick/App/AppDelegate.swift
! rg -q 'return axPreviews \\+ previewsForCGWindows' SnapClick/App/AppDelegate.swift
rg -q 'activateWindow\(id: CGWindowID, app: NSRunningApplication\)' SnapClick/App/AppDelegate.swift
rg -q 'activate\(_ preview: DockWindowPreview\)' SnapClick/App/AppDelegate.swift
rg -q '_AXUIElementGetWindow' SnapClick/App/AppDelegate.swift
rg -q 'CGSOrderWindow' SnapClick/App/AppDelegate.swift
rg -q 'thumbnailTilesByWindowID' SnapClick/App/AppDelegate.swift
rg -q 'loadedThumbnailWindowIDs' SnapClick/App/AppDelegate.swift
rg -q 'loadingThumbnailWindowIDs' SnapClick/App/AppDelegate.swift
rg -q 'captureThumbnail\(for: screenCaptureWindow, maxSize: maxSize\)' SnapClick/App/AppDelegate.swift
rg -q 'loadThumbnails\(' SnapClick/App/AppDelegate.swift
! rg -q 'thumbnailCache' SnapClick/App/AppDelegate.swift
rg -Fq 'panel.level = .popUpMenu' SnapClick/App/AppDelegate.swift
rg -Fq 'private final class PreviewPointerView' SnapClick/App/AppDelegate.swift
rg -Fq 'private func dockMaximumIconSize() -> CGFloat' SnapClick/App/AppDelegate.swift
rg -Fq 'dockPreferenceNumber("largesize")' SnapClick/App/AppDelegate.swift
rg -Fq 'panel.setFrame(panelFrame, display: true)' SnapClick/App/AppDelegate.swift
rg -Fq 'pointerView.frame = pointerFrame(' SnapClick/App/AppDelegate.swift
rg -Fq 'showPreview(for: currentDockApp)' SnapClick/App/AppDelegate.swift
rg -q 'windowID: CGWindowID\?' SnapClick/App/AppDelegate.swift
rg -q 'axWindow: AXUIElement\?' SnapClick/App/AppDelegate.swift
rg -q 'pidValue\(from item: \[String: Any\]\)' SnapClick/App/AppDelegate.swift
! rg -q 'copyCGWindows\(pid: app\.processIdentifier\)' SnapClick/App/AppDelegate.swift
rg -q 'numberValue\(in dict: \[String: Any\], key: String\)' SnapClick/App/AppDelegate.swift
rg -q 'handleDockMouseDown\(axPoint: CGPoint\)' SnapClick/App/AppDelegate.swift
rg -q 'handleDockMouseUp\(axPoint: CGPoint\)' SnapClick/App/AppDelegate.swift
rg -q 'pendingDockClick' SnapClick/App/AppDelegate.swift
rg -q 'shouldMinimizeOnDockClick\(app: NSRunningApplication, previews: \[DockWindowPreview\]\)' SnapClick/App/AppDelegate.swift
rg -q 'NSWorkspace.shared.frontmostApplication\?\.processIdentifier == app.processIdentifier' SnapClick/App/AppDelegate.swift
! rg -q 'pendingDockClick = \(dockApp, previews.contains \{ !\$0.isMinimized \}\)' SnapClick/App/AppDelegate.swift
rg -q 'setWindows\(_ previews: \[DockWindowPreview\], minimized: Bool\)' SnapClick/App/AppDelegate.swift
rg -q 'CGEvent\.tapCreate' SnapClick/App/AppDelegate.swift
rg -q 'options: \.listenOnly' SnapClick/App/AppDelegate.swift
rg -q 'previewPanel\?\.isVisible == true' SnapClick/App/AppDelegate.swift
rg -q 'previewAppPID == dockApp.app.processIdentifier' SnapClick/App/AppDelegate.swift
rg -q 'dockWindowControlDidChange' SnapClick/Core/AppSettings.swift
! rg -q 'dockWindowControlEnabled && !showInDock' SnapClick/Core/AppSettings.swift
! rg -q 'dockScrollVolume' SnapClick/Core/AppSettings.swift
! rg -q 'DockScrollVolume' SnapClick/App/AppDelegate.swift
! rg -q 'SystemOutputVolumeController' SnapClick/App/AppDelegate.swift
! rg -q 'Dock 滚轮调节音量' SnapClick/UI/MainWindow.swift SnapClick/Core/AppSettings.swift
! rg -q 'dockScrollVolumeEnabled' SnapClick/UI/MainWindow.swift
! rg -q 'fallbackDockRects\(\)' SnapClick/App/AppDelegate.swift
! rg -q 'dockAppElements\(in element' SnapClick/App/AppDelegate.swift
! rg -q 'addGlobalMonitorForEvents\(matching: \.leftMouseDown\)' SnapClick/App/AppDelegate.swift
! rg -q 'minimized \? nil : imageForMatchingWindow' SnapClick/App/AppDelegate.swift
! rg -q 'let axWindow: AXUIElement$' SnapClick/App/AppDelegate.swift
! rg -q 'super.init\(frame: NSRect\(x: 0, y: 0, width: 320' SnapClick/App/AppDelegate.swift
rg -q '截图包含边框投影' SnapClick/UI/MainWindow.swift
rg -q 'isOn: \$settings.screenshotAddShadow' SnapClick/UI/MainWindow.swift
rg -q 'screenshotAddShadow: Bool = true' SnapClick/Core/AppSettings.swift
