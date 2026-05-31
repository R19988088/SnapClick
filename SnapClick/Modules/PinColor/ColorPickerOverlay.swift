// ColorPickerOverlay.swift
// SnapClick - 贴图取色模块
// 取色覆盖层：冻结全屏背景 + 矩形放大镜 + 颜色信息面板，单击取色并复制

import AppKit
import SwiftUI

// MARK: - 覆盖层窗口控制器

final class ColorPickerOverlayWindowController: NSWindowController {

    convenience init() {
        let unionFrame = NSScreen.screens.reduce(CGRect.zero) { $0.union($1.frame) }
        let window = ColorPickerOverlayWindow(contentRect: unionFrame)
        self.init(window: window)
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSCursor.crosshair.push()
    }

    override func close() {
        NSCursor.pop()
        super.close()
    }
}

// MARK: - 覆盖层窗口

final class ColorPickerOverlayWindow: NSWindow {

    init(contentRect: CGRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        
        contentViewController = NSHostingController(
            rootView: ColorPickerOverlayView()
                .environmentObject(ColorPickerEngine.shared)
        )
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - 主覆盖层 SwiftUI 视图

struct ColorPickerOverlayView: View {
    @EnvironmentObject private var engine: ColorPickerEngine

    // 放大镜卡片尺寸
    private let magW: CGFloat = 348
    private let magH: CGFloat = 248
    // 颜色信息面板尺寸
    private let panelW: CGFloat = 348
    private let panelH: CGFloat = 196
    // 两卡片间距
    private let gap: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            ZStack {

                // ① 冻结的全屏背景（在覆盖层出现前已截好）
                if let capture = engine.fullScreenCapture {
                    Image(nsImage: capture)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    // 如果截图失败，显示半透明黑底，以便用户知道窗口弹出了
                    Color.black.opacity(0.2).ignoresSafeArea()
                }

                // ② 单击任意位置取色并复制
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        engine.confirmColor()
                    }

                // ③ 放大镜卡片 + 颜色信息卡片（随鼠标移动）
                VStack(spacing: gap) {
                    MagnifierCard(
                        image: engine.magnifierImage,
                        color: engine.currentColor,
                        width: magW,
                        height: magH
                    )
                    ColorInfoCard(
                        color: engine.currentColor,
                        engine: engine,
                        width: panelW,
                        height: panelH
                    )
                }
                // 不拦截下层 Color.clear 的点击事件
                .allowsHitTesting(false)
                .position(groupPosition(in: geo.size,
                                        totalW: magW,
                                        totalH: magH + gap + panelH))
            }
        }
        .ignoresSafeArea()
    }

    /// 计算整体组件中心坐标（光标右下偏移，自动贴边翻转）
    private func groupPosition(in containerSize: CGSize,
                               totalW: CGFloat,
                               totalH: CGFloat) -> CGPoint {
        let mouse = NSEvent.mouseLocation
        let screenH = NSScreen.main?.frame.height ?? containerSize.height
        let mouseY = screenH - mouse.y   // AppKit Y→SwiftUI Y 翻转

        let offsetX: CGFloat = 24
        let offsetY: CGFloat = 24

        var x = mouse.x + offsetX
        var y = mouseY  + offsetY

        // 右侧超出 → 翻到光标左侧
        if x + totalW / 2 > containerSize.width - 8 {
            x = mouse.x - offsetX - totalW / 2
        }
        // 下方超出 → 翻到光标上方
        if y + totalH / 2 > containerSize.height - 8 {
            y = mouseY - offsetY - totalH / 2
        }

        // 最终夹紧，确保不超出屏幕
        x = max(totalW / 2 + 8, min(containerSize.width  - totalW / 2 - 8, x))
        y = max(totalH / 2 + 8, min(containerSize.height - totalH / 2 - 8, y))

        return CGPoint(x: x, y: y)
    }
}

// MARK: - 放大镜卡片

struct MagnifierCard: View {
    let image: NSImage?
    let color: NSColor
    let width: CGFloat
    let height: CGFloat

    private let gridCols: Int = 29
    private let gridRows: Int = 21
    private let cornerRadius: CGFloat = 18

    // 深蓝黑背景（仿参考图）
    private let cardBg = Color(red: 0.10, green: 0.11, blue: 0.18)

    var body: some View {
        ZStack {
            // 深色背景底层
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(cardBg)

            // 放大的像素内容（.interpolation(.none) 保持像素锐利）
            if let img = image {
                Image(nsImage: img)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .opacity(0.72)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            }

            // 深色叠加（增强网格可读性）
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(cardBg.opacity(0.28))

            // 像素网格线
            MagnifierGrid(
                cols: gridCols, rows: gridRows,
                width: width, height: height,
                cornerRadius: cornerRadius
            )

            // 中心像素高亮框（当前颜色所在的像素）
            CenterPixelHighlight(
                cols: gridCols, rows: gridRows,
                width: width, height: height
            )

            // 右下角 ↘ 装饰（仿参考图风格）
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image(systemName: "arrow.down.right")
                        .font(.system(size: 11, weight: .light))
                        .foregroundColor(.white.opacity(0.30))
                        .padding(10)
                }
            }
        }
        .frame(width: width, height: height)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.55), radius: 24, x: 0, y: 8)
    }
}

// MARK: - 像素网格

struct MagnifierGrid: View {
    let cols: Int
    let rows: Int
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        Canvas { context, size in
            let cW = size.width  / CGFloat(cols)
            let cH = size.height / CGFloat(rows)
            let c  = Color.white.opacity(0.13)

            for i in 1..<cols {
                let x = cW * CGFloat(i)
                var p = Path(); p.move(to: .init(x: x, y: 0)); p.addLine(to: .init(x: x, y: size.height))
                context.stroke(p, with: .color(c), lineWidth: 0.5)
            }
            for i in 1..<rows {
                let y = cH * CGFloat(i)
                var p = Path(); p.move(to: .init(x: 0, y: y)); p.addLine(to: .init(x: size.width, y: y))
                context.stroke(p, with: .color(c), lineWidth: 0.5)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .allowsHitTesting(false)
    }
}

// MARK: - 中心像素高亮

struct CenterPixelHighlight: View {
    let cols: Int
    let rows: Int
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let cW = width  / CGFloat(cols)
        let cH = height / CGFloat(rows)
        ZStack {
            Rectangle()
                .stroke(Color.black.opacity(0.55), lineWidth: 2.5)
                .frame(width: cW + 1, height: cH + 1)
            Rectangle()
                .stroke(Color.white, lineWidth: 1.5)
                .frame(width: cW, height: cH)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 颜色信息面板

struct ColorInfoCard: View {
    let color: NSColor
    let engine: ColorPickerEngine
    let width: CGFloat
    let height: CGFloat

    private let cornerRadius: CGFloat = 18
    private let cardBg = Color(red: 0.09, green: 0.10, blue: 0.14)

    // 计算属性
    private var hex: String { engine.hexString(for: color) }
    private var rgb: (Int, Int, Int) {
        let c = color.usingColorSpace(.sRGB) ?? color
        return (Int(c.redComponent   * 255 + 0.5),
                Int(c.greenComponent * 255 + 0.5),
                Int(c.blueComponent  * 255 + 0.5))
    }
    private var hsb: (Int, Int, Int) {
        let c = color.usingColorSpace(.sRGB) ?? color
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (Int(h * 360 + 0.5), Int(s * 100 + 0.5), Int(b * 100 + 0.5))
    }

    var body: some View {
        let (r, g, b) = rgb
        let (h, s, bri) = hsb

        VStack(spacing: 0) {

            // ── 顶部：大色块 + HEX ───────────────────────────────
            HStack(alignment: .center, spacing: 14) {
                // 色块
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(nsColor: color))
                    .frame(width: 68, height: 68)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .shadow(color: Color(nsColor: color).opacity(0.5), radius: 8, x: 0, y: 3)

                VStack(alignment: .leading, spacing: 5) {
                    Text("HEX VALUE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.38))
                        .tracking(2.2)

                    Text(hex)
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 14)

            // ── 分隔线 ──────────────────────────────────────────
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 18)

            // ── 中部：RGB + HSB ──────────────────────────────────
            HStack(alignment: .top, spacing: 0) {
                // RGB 列
                VStack(alignment: .leading, spacing: 5) {
                    Text("RGB")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.38))
                        .tracking(1.5)
                    Text("\(r), \(g), \(b)")
                        .font(.system(size: 15, weight: .regular, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // HSB 列
                VStack(alignment: .leading, spacing: 5) {
                    Text("HSB")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.38))
                        .tracking(1.5)
                    Text("\(h), \(s)%, \(bri)%")
                        .font(.system(size: 15, weight: .regular, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            Spacer(minLength: 0)

            // ── 底部：单击取色提示按钮 ────────────────────────────
            HStack(spacing: 8) {
                Image(systemName: "cursorarrow.click")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.50))
                Text("单击取色并复制到剪贴板")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.60))
                    .tracking(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .frame(width: width, height: height)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(cardBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.55), radius: 24, x: 0, y: 8)
    }
}
