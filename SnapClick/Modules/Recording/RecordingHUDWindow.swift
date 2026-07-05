// RecordingHUDWindow.swift
// SnapClick - 录制中悬浮条控制面板
// 提供实时时间显示、闪烁红点指示器、暂停/停止/取消录制的操作控件

import AppKit
import SwiftUI
import Combine

// MARK: - 录屏中悬浮面板
final class RecordingHUDWindow: NSPanel {

    private static let positionXKey = "SnapClick.RecordingHUD.PositionX"
    private static let positionYKey = "SnapClick.RecordingHUD.PositionY"

    private static let defaultSize = CGSize(width: 232, height: 44)

    init(onPauseResume: @escaping () -> Void, onStop: @escaping () -> Void, onCancel: @escaping () -> Void) {
        let hudView = RecordingHUDView(
            onPauseResume: onPauseResume,
            onStop: onStop,
            onCancel: onCancel
        )

        let hostingView = NSHostingView(rootView: hudView)
        hostingView.frame = CGRect(origin: .zero, size: Self.defaultSize)

        let panelFrame = Self.resolveInitialFrame()

        super.init(
            contentRect: panelFrame,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        self.level = .statusBar
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.contentView = hostingView
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = true
        self.isMovable = true
        self.acceptsMouseMovedEvents = true

        // 整面 tracking，让 mouseEntered/mouseExited 切换 openHand 光标
        let trackArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        self.contentView?.addTrackingArea(trackArea)

        // 拖动结束后保存最新位置，下次录制时恢复
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowDidMove),
            name: NSWindow.didMoveNotification,
            object: self
        )
    }

    deinit {
        savePositionTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    private var savePositionTimer: Timer?

    @objc private func handleWindowDidMove() {
        // 防抖：拖动停止 0.4s 后再写入 UserDefaults，避免高频 IO
        savePositionTimer?.invalidate()
        savePositionTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            let origin = self.frame.origin
            UserDefaults.standard.set(Double(origin.x), forKey: Self.positionXKey)
            UserDefaults.standard.set(Double(origin.y), forKey: Self.positionYKey)
        }
    }

    // MARK: - 拖动光标：进入 HUD 显示 openHand，按下切换 closedHand
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        NSCursor.openHand.push()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        NSCursor.pop()
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        NSCursor.closedHand.push()
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        NSCursor.pop()
        NSCursor.openHand.push()
    }

    // MARK: - 屏幕边界约束
    // 防止用户把 HUD 拖到完全不可见的位置；至少保留 60×20 的可视区域
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        guard let targetScreen = screen ?? NSScreen.main else { return frameRect }
        let visible = targetScreen.visibleFrame
        let minVisible: CGFloat = 60
        let minVisibleHeight: CGFloat = 20

        var x = frameRect.origin.x
        var y = frameRect.origin.y

        x = max(visible.minX - frameRect.width + minVisible, x)
        x = min(visible.maxX - minVisible, x)
        y = max(visible.minY, y)
        y = min(visible.maxY - minVisibleHeight, y)

        return NSRect(x: x, y: y, width: frameRect.width, height: frameRect.height)
    }

    // MARK: - 初始位置：优先使用上次拖动后的位置
    private static func resolveInitialFrame() -> NSRect {
        if let saved = loadSavedFrame(), isFrameUsable(saved) {
            return saved
        }
        return defaultFrame()
    }

    private static func loadSavedFrame() -> CGRect? {
        guard let x = UserDefaults.standard.object(forKey: positionXKey) as? Double,
              let y = UserDefaults.standard.object(forKey: positionYKey) as? Double else {
            return nil
        }
        return CGRect(x: x, y: y, width: defaultSize.width, height: defaultSize.height)
    }

    // 校验：保存的位置是否仍然在某个屏幕的可见区域内（至少 50% 可见）
    private static func isFrameUsable(_ rect: CGRect) -> Bool {
        for screen in NSScreen.screens {
            let intersection = screen.frame.intersection(rect)
            if !intersection.isNull {
                let widthRatio = intersection.width / rect.width
                let heightRatio = intersection.height / rect.height
                if widthRatio >= 0.5 && heightRatio >= 0.5 {
                    return true
                }
            }
        }
        return false
    }

    private static func defaultFrame() -> CGRect {
        let screenFrame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        return CGRect(
            x: screenFrame.midX - defaultSize.width / 2,
            y: screenFrame.minY + 40,
            width: defaultSize.width,
            height: defaultSize.height
        )
    }
}

// MARK: - SwiftUI HUD 视图
struct RecordingHUDView: View {
    @ObservedObject private var engine = ScreenRecordingEngine.shared

    let onPauseResume: () -> Void
    let onStop: () -> Void
    let onCancel: () -> Void

    @State private var isRedDotVisible = true
    private let flashTimer = Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 12) {
            // 闪烁红色圆点
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .opacity(engine.isPaused ? 0.4 : (isRedDotVisible ? 1.0 : 0.2))
                .onReceive(flashTimer) { _ in
                    if !engine.isPaused {
                        isRedDotVisible.toggle()
                    } else {
                        isRedDotVisible = true
                    }
                }

            // 录制时间显示 (分:秒)
            Text(formatDuration(engine.recordingDuration))
                .font(.system(size: 13, weight: .bold).monospacedDigit())
                .foregroundColor(.white)
                .frame(width: 44)

            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1, height: 16)

            // 暂停/继续按钮
            Button(action: onPauseResume) {
                Image(systemName: engine.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Color(white: 1.0, opacity: 0.08))
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .help(engine.isPaused ? "继续录制" : "暂停录制")
            .accessibilityLabel(engine.isPaused ? "继续录制" : "暂停录制")

            // 停止按钮 - 保存录制并打开文件
            Button(action: onStop) {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 24, height: 24)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                }
            }
            .buttonStyle(.plain)
            .help("停止并保存")
            .accessibilityLabel("停止并保存")

            // 取消按钮 - 销毁性操作：放弃录制并删除文件
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 24, height: 24)
                    .background(Color(white: 1.0, opacity: 0.08))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help("取消并删除")
            .accessibilityLabel("取消并删除")
        }
        .padding(.horizontal, 12)
        .frame(width: 232, height: 44)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(white: 1.0, opacity: 0.12), lineWidth: 0.5)
                )
        )
        .colorScheme(.dark)

    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
