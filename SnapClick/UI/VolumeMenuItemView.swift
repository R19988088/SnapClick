import SwiftUI

struct VolumeMenuItemView: View {
    @ObservedObject private var controller = SoftwareVolumeController.shared

    private var volume: Binding<Double> {
        Binding(
            get: { Double(controller.gain) },
            set: { controller.setGain(Float32($0)) }
        )
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: controller.gain == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Slider(value: volume, in: 0...1)
                .disabled(controller.state != .active)
            Text("\(Int(controller.gain * 100))%")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(width: 280, height: 44)
    }
}
