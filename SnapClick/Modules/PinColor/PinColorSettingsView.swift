// PinColorSettingsView.swift
// SnapClick — 贴图 & 取色设置页（重构版，匹配 Stitch 设计图）

import SwiftUI
import AppKit

// MARK: - 颜色格式枚举

enum ColorFormat: String, CaseIterable, Identifiable {
    case hex  = "HEX"
    case rgb  = "RGB"
    case hsl  = "HSL"
    case hsb  = "HSB"
    case cmyk = "CMYK"
    case lab  = "Lab"
    var id: String { rawValue }
}

// MARK: - 设置页主视图

struct PinColorSettingsView: View {

    @EnvironmentObject private var engine:      ColorPickerEngine
    @EnvironmentObject private var pinManager:  PinWindowManager

    @AppStorage("PinColor.defaultColorFormat") private var defaultFormat: String  = ColorFormat.hex.rawValue
    @AppStorage("PinColor.previewFormats")     private var previewFormats: String = "HEX,RGB,HSL"
    @AppStorage("PinColor.pickerShortcut")     private var pickerShortcut: String = "⌥⇧C"
    @AppStorage("PinColor.pinShortcut")        private var pinShortcut: String    = "⌥⇧P"

    @State private var selectedTab: PinColorTab = .colorPicker

    enum PinColorTab: String, CaseIterable, Identifiable {
        case colorPicker = "colorPicker"
        case pinBoard    = "pinBoard"
        var id: String { rawValue }
        var label: String {
            switch self {
            case .colorPicker: return "取色器".localized
            case .pinBoard:    return "贴图板".localized
            }
        }
        var icon: String {
            switch self {
            case .colorPicker: return "eyedropper.halffull"
            case .pinBoard:    return "pin.circle.fill"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── 顶部 Tab 导航（与 Finder 页保持一致风格）─────────────────
            HStack(spacing: 0) {
                ForEach(PinColorTab.allCases) { tab in
                    PinColorTabButton(tab: tab, isSelected: selectedTab == tab) {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 1)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(DT.tabBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(DT.cardBorder, lineWidth: 0.75)
                    )
            )
            .frame(maxWidth: 360)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)

            // ── 内容区 ──────────────────────────────────────────────────
            Group {
                switch selectedTab {
                case .colorPicker:
                    ColorPickerSettingsTab(
                        engine: engine,
                        pickerShortcut: $pickerShortcut,
                        defaultFormat: $defaultFormat,
                        previewFormats: $previewFormats
                    )
                case .pinBoard:
                    PinBoardSettingsTab(
                        pinManager: pinManager,
                        pinShortcut: $pinShortcut
                    )
                }
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }
}

// MARK: - Tab 按钮

private struct PinColorTabButton: View {
    let tab: PinColorSettingsView.PinColorTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                Text(tab.label)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? .white : DT.unselectedTabText)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? DT.accent : Color.clear)
                    .padding(2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 取色器设置 Tab

private struct ColorPickerSettingsTab: View {
    let engine: ColorPickerEngine
    @Binding var pickerShortcut: String
    @Binding var defaultFormat: String
    @Binding var previewFormats: String

    /// 预览窗口固定显示的格式数量（与放大镜卡片布局保持一致）
    private let previewSlotCount = 3

    /// 解析 previewFormats 字符串为有序列表（保持用户选择顺序）
    private var previewList: [String] {
        previewFormats
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }
    }

    private var previewSet: Set<String> { Set(previewList) }

    /// 切换某个预览格式的勾选状态：始终保持恰好 previewSlotCount 项被选中
    /// - 点击已选中项：忽略（避免不足 3 项）
    /// - 点击未选中项：加入末尾，挤掉最早加入的那一项
    private func togglePreview(_ fmt: String) {
        var list = previewList
        if list.contains(fmt) { return }
        list.append(fmt)
        while list.count > previewSlotCount {
            list.removeFirst()
        }
        previewFormats = list.joined(separator: ",")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // ── BEHAVIOR 分组 ────────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(title: "行为设置".localized, icon: "slider.horizontal.3", color: .blue)

                DesignCard {
                    VStack(spacing: 0) {

                        // 全局快捷键行
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("全局快捷键".localized)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.customPrimaryText)
                                Text("在任意位置快速启动取色器".localized)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            // 快捷键标签组
                            HStack(spacing: 4) {
                                ForEach(splitShortcut(pickerShortcut), id: \.self) { key in
                                    KeyBadge(key: key)
                                }
                            }
                        }
                        .padding(.horizontal, DT.rowPadH)
                        .padding(.vertical, DT.rowPadV)

                        CardDivider()

                        // 默认格式行
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("默认复制格式".localized)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.customPrimaryText)
                                Text("点击色块时写入剪贴板的格式".localized)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            // 格式分段选择
                            HStack(spacing: 4) {
                                ForEach(ColorFormat.allCases) { fmt in
                                    FormatSelectBadge(
                                        label: fmt.rawValue,
                                        isSelected: defaultFormat == fmt.rawValue
                                    ) {
                                        defaultFormat = fmt.rawValue
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, DT.rowPadH)
                        .padding(.vertical, DT.rowPadV)

                        CardDivider()

                        // 预览窗口显示格式行（可多选）
                        // 描述文字较长，徽章组独占下方一行避免与左侧标题争抢横向空间
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("预览窗口显示格式".localized)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.customPrimaryText)
                                    Text("取色器实时预览中要显示哪些格式（可多选）".localized)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            HStack(spacing: 4) {
                                ForEach(ColorFormat.allCases) { fmt in
                                    FormatSelectBadge(
                                        label: fmt.rawValue,
                                        isSelected: previewSet.contains(fmt.rawValue)
                                    ) {
                                        togglePreview(fmt.rawValue)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, DT.rowPadH)
                        .padding(.vertical, DT.rowPadV)
                    }
                }
            }

            // ── 颜色历史 ──────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionLabel(title: "颜色历史".localized, icon: "clock.arrow.circlepath", color: .orange)
                    Spacer()
                    if !engine.colorHistory.isEmpty {
                        Button("清空".localized) {
                            engine.colorHistory.removeAll()
                        }
                        .buttonStyle(.borderless)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.red.opacity(0.8))
                    }
                }

                if engine.colorHistory.isEmpty {
                    // 空态
                    EmptyHistoryCard(
                        icon: "eyedropper",
                        message: "暂无颜色历史记录".localized,
                        hint: "使用取色器拾取颜色后将在此显示".localized
                    )
                } else {
                    DesignCard {
                        VStack(spacing: 0) {
                            // 颜色网格（每行10个大圆形）
                            LazyVGrid(
                                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 10),
                                spacing: 6
                            ) {
                                ForEach(Array(engine.colorHistory.prefix(20).enumerated()), id: \.offset) { _, color in
                                    NewColorHistoryCell(color: color, engine: engine)
                                }
                            }
                            .padding(14)
                        }
                    }
                }
            }

            // ── 提示横幅 ──────────────────────────────────────────────
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(DT.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("使用提示".localized)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.customPrimaryText)
                    Text("按下快捷键后，将鼠标悬停在目标颜色上并单击即可拾取，支持屏幕任意位置。".localized)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: DT.cardRadius, style: .continuous)
                    .fill(DT.infoBannerBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: DT.cardRadius, style: .continuous)
                            .stroke(DT.infoBannerBorder, lineWidth: 0.75)
                    )
            )
        }
    }

    /// 将 "⌥⇧C" 拆成 ["⌥", "⇧", "C"]
    private func splitShortcut(_ s: String) -> [String] {
        let modifiers: [Character] = ["⌘", "⌥", "⇧", "⌃", "⇥", "↩"]
        var result: [String] = []
        var remaining = s
        for mod in modifiers {
            if remaining.contains(mod) {
                result.append(String(mod))
                remaining.removeAll { $0 == mod }
            }
        }
        if !remaining.isEmpty { result.append(remaining.uppercased()) }
        return result
    }
}

// MARK: - 格式选择 Badge

private struct FormatSelectBadge: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(isSelected ? .white : DT.unselectedTabText)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isSelected ? DT.accent : DT.tabBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(isSelected ? DT.accent : DT.cardBorder, lineWidth: 0.75)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 新版颜色历史单元格（大圆形）

struct NewColorHistoryCell: View {
    let color: NSColor
    let engine: ColorPickerEngine

    @State private var isHovered = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(nsColor: color))
                .shadow(
                    color: Color(nsColor: color).opacity(isHovered ? 0.5 : 0.2),
                    radius: isHovered ? 6 : 2,
                    x: 0, y: isHovered ? 3 : 1
                )
                .overlay(
                    Circle()
                        .stroke(
                            isHovered ? Color.white.opacity(0.6) : Color.clear,
                            lineWidth: 2
                        )
                )
                .scaleEffect(isHovered ? 1.12 : 1.0)

            if isHovered {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 1)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .onHover { h in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                isHovered = h
            }
        }
        .onTapGesture {
            let text = engine.formattedString(for: color)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
        .help(engine.formattedString(for: color))
        .accessibilityLabel("\(engine.formattedString(for: color))，点击复制")
    }
}

// MARK: - 贴图板设置 Tab

private struct PinBoardSettingsTab: View {
    let pinManager: PinWindowManager
    @Binding var pinShortcut: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // ── Pin Hotkey 卡片 ───────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(title: "贴图快捷键".localized, icon: "keyboard", color: .indigo)

                DesignCard {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.indigo.opacity(0.1))
                                .frame(width: 36, height: 36)
                            Image(systemName: "pin.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(.indigo)
                        }
                        .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("全局贴图快捷键".localized)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.customPrimaryText)
                            Text("从剪贴板抓取图片并钉在屏幕上".localized)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            ForEach(splitShortcut(pinShortcut), id: \.self) { key in
                                KeyBadge(key: key)
                            }
                        }
                    }
                    .padding(.horizontal, DT.rowPadH)
                    .padding(.vertical, DT.rowPadV)
                }
            }

            // ── 窗口控制 ──────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(title: "窗口控制".localized, icon: "square.stack.3d.up", color: .teal)

                DesignCard {
                    HStack(spacing: 12) {
                        WindowControlButton(
                            icon: "eye.fill",
                            label: "显示全部".localized,
                            color: DT.accent
                        ) { pinManager.showAll() }

                        Divider().frame(height: 20)

                        WindowControlButton(
                            icon: "eye.slash",
                            label: "隐藏全部".localized,
                            color: DT.unselectedTabText
                        ) { pinManager.hideAll() }

                        Divider().frame(height: 20)

                        WindowControlButton(
                            icon: "xmark.circle",
                            label: "关闭全部".localized,
                            color: .red
                        ) { pinManager.closeAll() }
                    }
                    .padding(.horizontal, DT.rowPadH)
                    .padding(.vertical, DT.rowPadV + 2)
                }
            }

            // ── 贴图历史库 ────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionLabel(
                        title: pinManager.pinHistory.isEmpty
                            ? "贴图历史".localized
                            : "贴图历史（\(pinManager.pinHistory.count) 张）".localized,
                        icon: "photo.stack",
                        color: .purple
                    )
                    Spacer()
                    if !pinManager.pinHistory.isEmpty {
                        Button("清空".localized) {
                            pinManager.clearHistory()
                        }
                        .buttonStyle(.borderless)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.red.opacity(0.8))
                    }
                }

                if pinManager.pinHistory.isEmpty {
                    EmptyHistoryCard(
                        icon: "pin.slash",
                        message: "暂无贴图历史".localized,
                        hint: "使用贴图功能钉上图片后将在此显示最近记录".localized
                    )
                } else {
                    DesignCard {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 10) {
                                ForEach(pinManager.pinHistory) { item in
                                    NewPinHistoryCell(item: item, manager: pinManager)
                                }
                            }
                            .padding(12)
                        }
                        .frame(height: 114)
                    }
                }
            }
        }
    }

    private func splitShortcut(_ s: String) -> [String] {
        let modifiers: [Character] = ["⌘", "⌥", "⇧", "⌃", "⇥", "↩"]
        var result: [String] = []
        var remaining = s
        for mod in modifiers {
            if remaining.contains(mod) {
                result.append(String(mod))
                remaining.removeAll { $0 == mod }
            }
        }
        if !remaining.isEmpty { result.append(remaining.uppercased()) }
        return result
    }
}

// MARK: - 窗口控制按钮

private struct WindowControlButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(label)
                    .font(.system(size: 12.5, weight: .medium))
            }
            .foregroundStyle(isHovered ? color : DT.unselectedTabText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isHovered ? color.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

// MARK: - 空态占位卡

struct EmptyHistoryCard: View {
    let icon: String
    let message: String
    let hint: String

    var body: some View {
        DesignCard {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(DT.placeholderText)
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.customSecondaryText)
                Text(hint)
                    .font(.system(size: 11))
                    .foregroundStyle(DT.placeholderText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        }
    }
}

// MARK: - 新版贴图历史单元格

struct NewPinHistoryCell: View {
    let item: PinHistoryItem
    let manager: PinWindowManager

    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 图片主体
            Group {
                if let img = item.nsImage {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    DT.tabBg
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 20))
                                .foregroundStyle(.secondary)
                        )
                }
            }
            .frame(width: 90, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        isHovered ? DT.accent.opacity(0.5) : DT.cardBorder,
                        lineWidth: isHovered ? 1.5 : 0.75
                    )
            )
            .scaleEffect(isHovered ? 1.04 : 1.0)
            .shadow(
                color: isHovered ? Color.black.opacity(0.12) : Color.clear,
                radius: 6, x: 0, y: 3
            )

            // 悬停时显示关闭按钮
            if isHovered {
                Button {
                    manager.removeHistory(item)
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 18, height: 18)
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .padding(4)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onHover { h in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                isHovered = h
            }
        }
        .onTapGesture { manager.pinFromHistory(item) }
        .help("单击重新钉上 · \(formattedDate(item.createdAt))")
    }

    private func formattedDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }
}

// MARK: - 兼容旧版组件名（ColorHistoryCell / PinHistoryCell）

typealias ColorHistoryCell = NewColorHistoryCell

// MARK: - 快捷键展示（ShortcutDisplayField，保持兼容）

struct ShortcutDisplayField: View {
    @Binding var shortcut: String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(shortcut.enumerated()), id: \.offset) { _, char in
                KeyBadge(key: String(char))
            }
        }
    }
}

// MARK: - 预览

#Preview {
    PinColorSettingsView()
        .environmentObject(ColorPickerEngine.shared)
        .environmentObject(PinWindowManager.shared)
        .frame(width: 600, height: 500)
}
