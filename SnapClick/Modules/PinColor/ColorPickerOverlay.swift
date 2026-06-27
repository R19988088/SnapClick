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
        
        let hostingView = NSHostingView(
            rootView: ColorPickerOverlayView()
                .environmentObject(ColorPickerEngine.shared)
        )
        hostingView.autoresizingMask = [.width, .height]
        contentView = hostingView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - 主覆盖层 SwiftUI 视图

struct ColorPickerOverlayView: View {
    @EnvironmentObject private var engine: ColorPickerEngine

    // 整合后的单卡片尺寸
    private let cardW: CGFloat = 260
    private let cardH: CGFloat = 290

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
                    Color.black.opacity(0.2).ignoresSafeArea()
                }

                // ② 单击任意位置取色并复制
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        engine.confirmColor()
                    }

                // ③ 整合卡片（随鼠标移动）
                MagnifierCard(
                    image: engine.magnifierImage,
                    color: engine.currentColor,
                    engine: engine,
                    width: cardW,
                    height: cardH
                )
                // 不拦截下层 Color.clear 的点击事件
                .allowsHitTesting(false)
                .position(groupPosition(in: geo.size,
                                        totalW: cardW,
                                        totalH: cardH,
                                        bottomPad: 34))
            }
        }
        .ignoresSafeArea()
    }

    /// 计算整体组件中心坐标（默认显示在光标左上角，超出边界时自动翻转）
    /// bottomPad: 卡片底部面板高度，用于让放大镜（而非提示文字）对齐鼠标
    private func groupPosition(in containerSize: CGSize,
                               totalW: CGFloat,
                               totalH: CGFloat,
                               bottomPad: CGFloat = 0) -> CGPoint {
        let mouse = NSEvent.mouseLocation
        // AppKit Y 轴（从下往上）→ SwiftUI Y 轴（从下往下）翻转
        let mouseY = containerSize.height - mouse.y

        // 与鼠标的间距（极致贴紧光标）
        let offsetX: CGFloat = 1
        let offsetY: CGFloat = 1

        // 卡片底边对齐鼠标，再向上偏移 bottomPad，
        // 使得放大镜底边（而非提示文字区）紧贴鼠标
        var x = mouse.x - offsetX - totalW / 2
        var y = mouseY  - offsetY - totalH / 2 + bottomPad

        // 左侧超出 → 翻到光标右侧
        if x - totalW / 2 < 8 {
            x = mouse.x + offsetX + totalW / 2
        }
        // 上方超出 → 翻到光标下方
        if y - totalH / 2 < 8 {
            y = mouseY + offsetY + totalH / 2 - bottomPad
        }

        // 最终夹紧，确保不超出屏幕边缘
        x = max(totalW / 2 + 8, min(containerSize.width  - totalW / 2 - 8, x))
        y = max(totalH / 2 + 8, min(containerSize.height - totalH / 2 - 8, y))

        return CGPoint(x: x, y: y)
    }
}

// MARK: - 整合放大镜卡片（顶部色值 + 中部放大镜 + 底部提示）

struct MagnifierCard: View {
    let image: NSImage?
    let color: NSColor
    let engine: ColorPickerEngine
    let width: CGFloat
    let height: CGFloat

    // 跟随设置中的「默认复制格式」实时更新
    @AppStorage("PinColor.defaultColorFormat") private var defaultFormat: String = "HEX"
    /// 用户选择要在预览窗口中显示的格式列表（逗号分隔，与设置面板一致），默认 3 项
    @AppStorage("PinColor.previewFormats") private var previewFormats: String = "HEX,RGB,HSL"

    // 顶部文字区高度、底部提示区高度
    private let topTextH: CGFloat = 104
    private let bottomHintH: CGFloat = 34
    private var magAreaH: CGFloat { height - topTextH - bottomHintH }

    private let gridCols: Int = 25
    private let gridRows: Int = 17
    private let cornerRadius: CGFloat = 16

    private let cardBg = Color(red: 0.10, green: 0.11, blue: 0.18)

    // 浅色卡片底配色
    private let panelBg    = Color(red: 0.96, green: 0.96, blue: 0.97)
    private let panelBorder = Color.black.opacity(0.10)

    // 高对比度的标签/数值文字配色
    private let labelColor = Color(red: 0.38, green: 0.40, blue: 0.46)
    private let valueColor = Color(red: 0.10, green: 0.12, blue: 0.18)
    private let accentBlue = Color(red: 0.10, green: 0.40, blue: 0.92)

    // 主格式（用户在设置中选择的，将以大字 + 蓝色突出显示，并写入剪贴板）
    private var primaryFormat: String { defaultFormat.uppercased() }
    private var primaryValue: String { formattedString(primaryFormat) }

    /// 次要展示的格式列表：取用户设置的 previewFormats，剔除当前主格式
    private var secondaryFormats: [String] {
        let raw = previewFormats
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }
        let filtered = raw.filter { $0 != primaryFormat }
        // 最多展示 4 个，避免布局溢出
        return Array(filtered.prefix(4))
    }

    private func formattedString(_ fmt: String) -> String {
        switch fmt {
        case "RGB":  return engine.rgbString(for: color)
        case "HSL":  return engine.hslString(for: color)
        case "HSB":  return engine.hsbString(for: color)
        case "CMYK": return engine.cmykString(for: color)
        case "LAB":  return engine.labString(for: color)
        default:     return engine.hexString(for: color)
        }
    }

    /// 标签显示文本（Lab 保留大小写美观）
    private func displayLabel(_ fmt: String) -> String {
        fmt == "LAB" ? "Lab" : fmt
    }

    /// 显示用：剥掉格式前缀与括号，只保留数值（HEX 保留 # 前缀作为视觉锚点）
    /// 同时去掉逗号后的空格，让窄列也能完整显示
    private func displayValue(_ fmt: String) -> String {
        let s = formattedString(fmt)
        let inside: String
        if let lp = s.firstIndex(of: "("), let rp = s.lastIndex(of: ")") {
            inside = String(s[s.index(after: lp)..<rp])
        } else {
            inside = s
        }
        return inside.replacingOccurrences(of: ", ", with: ",")
    }

    var body: some View {
        // 当次要格式较多（>=3）时，把第 1 项挪到主格式右上角，剩余在第三行平铺，提高空间利用率
        let secondaries = secondaryFormats
        let topRightFmt: String? = secondaries.count >= 3 ? secondaries.first : nil
        let bottomFmts: [String] = topRightFmt != nil ? Array(secondaries.dropFirst()) : secondaries

        return VStack(spacing: 6) {

            // ── 浅色面板：顶部信息 + 放大镜（带背景 + 阴影） ─────
            VStack(spacing: 0) {

                // ── 顶部：主格式（大字蓝色） + 右上角次要 + 底部参考 ──
                VStack(alignment: .leading, spacing: 0) {
                    // 第一行：左主格式标签 + 右上角次要格式标签
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(displayLabel(primaryFormat))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(labelColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let fmt = topRightFmt {
                            Text(displayLabel(fmt))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(labelColor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.bottom, 2)

                    // 第二行：主格式大字 + 右上角次要数值
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(displayValue(primaryFormat))
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(accentBlue)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let fmt = topRightFmt {
                            Text(displayValue(fmt))
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(valueColor.opacity(0.85))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.bottom, 10)

                    // 第三行：剩余次要参考格式平铺
                    if !bottomFmts.isEmpty {
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(Array(bottomFmts.enumerated()), id: \.offset) { _, fmt in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(displayLabel(fmt))
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(labelColor)
                                    Text(displayValue(fmt))
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundColor(valueColor.opacity(0.85))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .frame(height: topTextH, alignment: .bottom)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)

                // ── 中部：放大镜像素区域 ──────────────────────────
                ZStack {
                    // 深色底（保证网格和像素可读）
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(cardBg)

                    // 放大的像素内容
                    if let img = image {
                        Image(nsImage: img)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFill()
                            .frame(width: width, height: magAreaH)
                            .opacity(0.75)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    }

                    // 深色叠加（增强网格可读性）
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(cardBg.opacity(0.22))

                    // 像素网格线
                    MagnifierGrid(
                        cols: gridCols, rows: gridRows,
                        width: width, height: magAreaH,
                        cornerRadius: cornerRadius
                    )

                    // 中心像素高亮框
                    CenterPixelHighlight(
                        cols: gridCols, rows: gridRows,
                        width: width, height: magAreaH
                    )
                }
                .frame(width: width, height: magAreaH)
            }
            .frame(width: width)
            .background(
                // 浅色卡片底
                RoundedRectangle(cornerRadius: cornerRadius + 4, style: .continuous)
                    .fill(panelBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius + 4, style: .continuous)
                    .strokeBorder(panelBorder, lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 18, x: 0, y: 8)

            // ── 底部：纯文字提示（无背景，蓝色字体） ─────────────
            Text("单击取色并复制到剪贴板".localized)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(accentBlue)
                .tracking(0.5)
                .frame(height: bottomHintH)
                .frame(maxWidth: .infinity)
        }
        .frame(width: width, height: height)
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


