// RecordingHUDWindow.swift
// SnapClick - 录制中悬浮条控制面板
// 提供实时时间显示、闪烁红点指示器、暂停与停止录制的操作控件

import AppKit
import SwiftUI
import Combine

// MARK: - 录屏中悬浮面板
final class RecordingHUDWindow: NSPanel {
    
    init(onPauseResume: @escaping () -> Void, onStop: @escaping () -> Void) {
        let hudView = RecordingHUDView(
            onPauseResume: onPauseResume,
            onStop: onStop
        )
        
        let hostingView = NSHostingView(rootView: hudView)
        hostingView.frame = CGRect(x: 0, y: 0, width: 170, height: 44)
        
        let screenFrame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        // 默认放置在屏幕下方中央偏上位置
        let panelFrame = CGRect(
            x: screenFrame.midX - 85,
            y: screenFrame.origin.y + 40,
            width: 170,
            height: 44
        )
        
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
    }
}

// MARK: - SwiftUI HUD 视图
struct RecordingHUDView: View {
    @ObservedObject private var engine = ScreenRecordingEngine.shared
    
    let onPauseResume: () -> Void
    let onStop: () -> Void
    
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
            
            // 停止按钮
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
        }
        .padding(.horizontal, 12)
        .frame(width: 170, height: 44)
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
