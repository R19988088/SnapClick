import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct InputSourceSettingsView: View {
    @ObservedObject private var controller = InputSourceController.shared
    @State private var selectedExceptionID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(title: "输入法偏好".localized, icon: "text.cursor", color: DT.accent)

                DesignCard {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("首选输入法".localized)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.customPrimaryText)
                            Text("普通应用统一使用此输入法".localized)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if controller.availableSources.isEmpty {
                            Text("没有可用的输入法".localized)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("", selection: preferredSourceBinding) {
                                ForEach(controller.availableSources) { source in
                                    Text(source.name).tag(source.id)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 190)
                        }
                    }
                    .padding(.horizontal, DT.rowPadH)
                    .padding(.vertical, DT.rowPadV)

                    CardDivider()

                    ToggleRow(
                        title: "保留用户选择".localized,
                        description: "手动切换后，将新输入法设为首选".localized,
                        isOn: retainSelectionBinding
                    )
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(title: "例外应用".localized, icon: "app.badge", color: DT.accent)
                Text("以下应用忽略首选输入法并使用系统规则".localized)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            DesignCard {
                if controller.exceptions.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(DT.placeholderText)
                        Text("暂无例外应用".localized)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                } else {
                    ScrollView(.vertical, showsIndicators: controller.exceptions.count > 4) {
                        LazyVStack(spacing: 0) {
                            ForEach(controller.exceptions) { exception in
                                exceptionRow(exception)
                                if exception.id != controller.exceptions.last?.id {
                                    CardDivider()
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 280)
                }

                CardDivider()

                HStack(spacing: 4) {
                    Button {
                        addException()
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 22, height: 20)
                    }
                    .buttonStyle(.plain)
                    .help("添加例外应用".localized)
                    .accessibilityLabel("添加例外应用".localized)

                    Button {
                        if let selectedExceptionID {
                            controller.removeException(bundleID: selectedExceptionID)
                            self.selectedExceptionID = nil
                        }
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 22, height: 20)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedExceptionID == nil)
                    .help("移除例外应用".localized)
                    .accessibilityLabel("移除例外应用".localized)

                    Spacer()
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.customSecondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
            }
        }
    }

    private var preferredSourceBinding: Binding<String> {
        Binding(
            get: { controller.preferredInputSourceID },
            set: { controller.preferredInputSourceID = $0 }
        )
    }

    private var retainSelectionBinding: Binding<Bool> {
        Binding(
            get: { controller.retainUserSelection },
            set: { controller.retainUserSelection = $0 }
        )
    }

    private func exceptionRow(_ exception: InputSourceException) -> some View {
        Button {
            selectedExceptionID = exception.bundleID
        } label: {
            HStack(spacing: 10) {
                Image(nsImage: controller.icon(for: exception))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(exception.name)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.customPrimaryText)
                        .lineLimit(1)
                    Text(exception.bundleID)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
            }
            .padding(.horizontal, DT.rowPadH)
            .padding(.vertical, 8)
            .background(
                selectedExceptionID == exception.bundleID
                    ? DT.accent.opacity(0.10)
                    : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func addException() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.prompt = "选择应用".localized
        guard panel.runModal() == .OK, let url = panel.url else { return }
        controller.addException(applicationURL: url)
        selectedExceptionID = Bundle(url: url)?.bundleIdentifier
    }
}
