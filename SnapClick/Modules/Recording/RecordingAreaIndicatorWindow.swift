// RecordingAreaIndicatorWindow.swift
// SnapClick - 录屏选区/窗口四角闪烁蓝色标识窗口
// 在物理屏幕上提供高品质的录制边界指示，且完全不被 SCStream 录入视频，鼠标事件 100% 穿透

import AppKit
import SwiftUI

// MARK: - 录制区域呼吸闪烁蓝色指示 View
struct RecordingAreaIndicatorView: View {
    @State private var isVisible = true
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 左上角 L 型
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 20))
                    path.addLine(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 20, y: 0))
                }
                .stroke(Color.blue, lineWidth: 4)
                
                // 右上角 L 型
                Path { path in
                    path.move(to: CGPoint(x: geo.size.width - 20, y: 0))
                    path.addLine(to: CGPoint(x: geo.size.width, y: 0))
                    path.addLine(to: CGPoint(x: geo.size.width, y: 20))
                }
                .stroke(Color.blue, lineWidth: 4)
                
                // 左下角 L 型
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geo.size.height - 20))
                    path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                    path.addLine(to: CGPoint(x: 20, y: geo.size.height))
                }
                .stroke(Color.blue, lineWidth: 4)
                
                // 右下角 L 型
                Path { path in
                    path.move(to: CGPoint(x: geo.size.width - 20, y: geo.size.height))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height - 20))
                }
                .stroke(Color.blue, lineWidth: 4)
            }
            .opacity(isVisible ? 1.0 : 0.15)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isVisible)
            .onAppear {
                isVisible = false
            }
        }
    }
}

// MARK: - 录屏四角蓝色指示器窗口 (忽略鼠标事件，层级高)
final class RecordingAreaIndicatorWindow: NSWindow {
    
    init(recordingRect: CGRect) {
        // 向外扩展 3 像素以完美贴合录制选区边界，避免挡住被录像内容，也更便于 SCStream 裁剪过滤
        let padding: CGFloat = 3
        let frame = recordingRect.insetBy(dx: -padding, dy: -padding)
        
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.level = .screenSaver
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = true // 100% 穿透鼠标
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let view = RecordingAreaIndicatorView()
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(origin: .zero, size: frame.size)
        self.contentView = hostingView
    }
}
