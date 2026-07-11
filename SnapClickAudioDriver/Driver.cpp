#include <aspl/Driver.hpp>

#include <CoreAudio/AudioServerPlugIn.h>

#include <memory>

namespace {

constexpr UInt32 SampleRate = 48000;
constexpr UInt32 ChannelCount = 2;
constexpr const char* DeviceUID = "com.snapclick.audio.control";

AudioStreamBasicDescription streamFormat() {
    return AudioStreamBasicDescription {
        .mSampleRate = SampleRate,
        .mFormatID = kAudioFormatLinearPCM,
        .mFormatFlags = kAudioFormatFlagIsFloat |
                        kAudioFormatFlagsNativeEndian |
                        kAudioFormatFlagIsPacked,
        .mBytesPerPacket = ChannelCount * sizeof(Float32),
        .mFramesPerPacket = 1,
        .mBytesPerFrame = ChannelCount * sizeof(Float32),
        .mChannelsPerFrame = ChannelCount,
        .mBitsPerChannel = 8 * sizeof(Float32),
        .mReserved = 0,
    };
}

std::shared_ptr<aspl::Driver> createDriver() {
    auto tracer = std::make_shared<aspl::Tracer>(aspl::Tracer::Mode::Noop);
    auto context = std::make_shared<aspl::Context>(tracer);

    aspl::DeviceParameters parameters;
    parameters.Name = "SnapClick Control Output";
    parameters.Manufacturer = "SnapClick";
    parameters.DeviceUID = DeviceUID;
    parameters.ModelUID = "com.snapclick.audio.control.model";
    parameters.SampleRate = SampleRate;
    parameters.ChannelCount = ChannelCount;
    parameters.EnableMixing = true;
    parameters.ZeroTimeStampPeriod = 512;

    auto device = std::make_shared<aspl::Device>(context, parameters);
    aspl::StreamParameters output;
    output.Direction = aspl::Direction::Output;
    output.Format = streamFormat();
    device->AddStreamWithControlsAsync(output);

    auto plugin = std::make_shared<aspl::Plugin>(context);
    plugin->AddDevice(device);
    return std::make_shared<aspl::Driver>(context, plugin);
}

} // namespace

extern "C" void* SnapClickAudioEntryPoint(CFAllocatorRef, CFUUIDRef typeUUID) {
    if (!CFEqual(typeUUID, kAudioServerPlugInTypeUUID)) {
        return nullptr;
    }
    static std::shared_ptr<aspl::Driver> driver = createDriver();
    return driver->GetReference();
}
