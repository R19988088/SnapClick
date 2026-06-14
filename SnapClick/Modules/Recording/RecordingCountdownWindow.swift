// RecordingCountdownWindow.swift
// SnapClick - 录屏启动倒计时窗口
// 在正式开启视频流前，于屏幕正中央显示醒目的弹簧缩放 3D 倒计时动画，并支持 ESC 随时中止

import AppKit
import SwiftUI

// MARK: - 倒计时全屏遮罩窗口
final class RecordingCountdownWindow: NSWindow {
    
    private let onFinished: () -> Void
    private let onCancelled: () -> Void
    
    private var seconds: Int
    private var timer: Timer?
    private let hostingView: NSHostingView<CountdownView>
    
    init(seconds: Int, onFinished: @escaping () -> Void, onCancelled: @escaping () -> Void) {
        self.seconds = seconds
        self.onFinished = onFinished
        self.onCancelled = onCancelled
        
        let screenFrame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = CGRect(
            x: screenFrame.midX - 200,
            y: screenFrame.midY - 200,
            width: 400,
            height: 400
        )
        
        let countdownView = CountdownView(seconds: seconds)
        self.hostingView = NSHostingView(rootView: countdownView)
        hostingView.frame = CGRect(x: 0, y: 0, width: 400, height: 400)
        
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 3)
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.contentView = hostingView
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        startTimer()
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC 键
            cancelCountdown()
        }
    }
    
    private func startTimer() {
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // 使用 MainActor 调度以确保主线程刷新 UI
            DispatchQueue.main.async {
                self.seconds -= 1
                if self.seconds > 0 {
                    self.hostingView.rootView = CountdownView(seconds: self.seconds)
                } else if self.seconds == 0 {
                    self.hostingView.rootView = CountdownView(seconds: 0)
                    
                    // 显示 "Go!" 0.6 秒后再正式启动，体验更佳
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        self.finishCountdown()
                    }
                }
            }
        }
    }
    
    private func finishCountdown() {
        self.timer?.invalidate()
        self.timer = nil
        self.orderOut(nil)
        self.onFinished()
    }
    
    private func cancelCountdown() {
        self.timer?.invalidate()
        self.timer = nil
        self.orderOut(nil)
        self.onCancelled()
    }
}

// MARK: - SwiftUI 倒计时渲染视图
struct CountdownView: View {
    let seconds: Int
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0
    
    var body: some View {
        ZStack {
            if seconds > 0 {
                Text("\(seconds)")
                    .font(.system(size: 160, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .id(seconds) // 强制每次数字改变时重新生成视图，触发 Appear 动画
                    .onAppear {
                        scale = 0.3
                        opacity = 0.0
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                            scale = 1.0
                            opacity = 1.0
                        }
                    }
            } else {
                Text("Go!")
                    .font(.system(size: 130, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 34/255, green: 197/255, blue: 94/255)) // Tailwind Green-500
                    .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .onAppear {
                        scale = 0.4
                        opacity = 0.0
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                            scale = 1.0
                            opacity = 1.0
                        }
                    }
            }
        }
        .frame(width: 400, height: 400)
    }
}
