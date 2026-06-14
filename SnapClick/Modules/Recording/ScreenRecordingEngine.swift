// ScreenRecordingEngine.swift
// SnapClick - 屏幕录制模块核心引擎
// 使用 ScreenCaptureKit (macOS 12.3+) 实现屏幕录制功能，集成专属选区层、HUD 控制浮条以及多音轨麦克风捕获

import ScreenCaptureKit
import AVFoundation
import AppKit
import Combine

// MARK: - 录制错误类型
enum ScreenRecordingError: LocalizedError {
    case permissionDenied
    case noScreenAvailable
    case alreadyRecording
    case notRecording
    case setupFailed(String)
    case saveFailed(String)
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .permissionDenied:      return "没有屏幕录制权限，请在系统设置中授权"
        case .noScreenAvailable:     return "未找到可用的屏幕"
        case .alreadyRecording:      return "录制已在进行中"
        case .notRecording:          return "当前没有进行录制"
        case .setupFailed(let msg):  return "录制配置失败：\(msg)"
        case .saveFailed(let msg):   return "保存录制失败：\(msg)"
        case .userCancelled:         return "用户取消了录制"
        }
    }
}

// MARK: - 录制引擎（主 Actor）
@MainActor
final class ScreenRecordingEngine: NSObject, ObservableObject {

    // MARK: 单例
    static let shared = ScreenRecordingEngine()

    // MARK: 发布属性
    @Published var isRecording: Bool = false
    @Published var isPaused: Bool = false
    @Published var recordingDuration: TimeInterval = 0

    // MARK: 私有属性
    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput? // 系统音频输入
    private var micInput: AVAssetWriterInput?   // 麦克风音频输入
    private var outputURL: URL?
    private var durationTimer: AnyCancellable?
    private var recordingStartTime: CMTime = .zero
    private var firstSample = true

    // 麦克风录制会话
    private var micSession: AVCaptureSession?

    // 暂停/继续时间差参数
    private var timeOffset: CMTime = .zero
    private var lastAppendedPTS: CMTime = .zero
    private var needsResumeAdjustment = false

    // UI 组件引用
    private var selectionOverlayWindow: RecordSelectionOverlayWindow?
    private var overlayContinuation: CheckedContinuation<(CGRect?, SCWindow?), Error>?
    private var hudWindow: RecordingHUDWindow?
    private var countdownWindow: RecordingCountdownWindow?
    private var areaIndicatorWindow: RecordingAreaIndicatorWindow?

    private override init() {
        super.init()
    }


    // MARK: - 公共接口：选区录制
    func startAreaRecording() async throws {
        guard !isRecording else { throw ScreenRecordingError.alreadyRecording }
        guard PermissionManager.shared.hasScreenRecordingPermission else {
            throw ScreenRecordingError.permissionDenied
        }

        // 先截取底图供覆盖层显示
        guard let cgImage = CGDisplayCreateImage(CGMainDisplayID()) else {
            throw ScreenRecordingError.noScreenAvailable
        }
        let scale = NSScreen.main?.backingScaleFactor ?? 1.0
        let bgImage = NSImage(cgImage: cgImage,
                              size: NSSize(width: CGFloat(cgImage.width) / scale,
                                           height: CGFloat(cgImage.height) / scale))

        // 显示专属选区覆盖层等待用户拖拽和配置参数
        let (selectedRect, selectedWindow) = try await showSelectionOverlay(background: bgImage)
        guard let rect = selectedRect else {
            throw ScreenRecordingError.userCancelled
        }

        // 提前显示四角闪烁标识，让用户在倒计时期间明确录制范围
        let indicator = RecordingAreaIndicatorWindow(recordingRect: rect)
        self.areaIndicatorWindow = indicator
        indicator.orderFrontRegardless()

        // 倒计时（如设置）
        do {
            try await performCountdown()
        } catch {
            // 若倒计时被中途取消，及时销毁指示器窗口
            areaIndicatorWindow?.orderOut(nil)
            areaIndicatorWindow = nil
            throw error
        }

        // 开始录制选定区域
        try await startRecording(captureRect: rect, targetWindow: selectedWindow)
    }

    // MARK: - 公共接口：全屏录制
    func startFullScreenRecording() async throws {
        guard !isRecording else { throw ScreenRecordingError.alreadyRecording }
        guard PermissionManager.shared.hasScreenRecordingPermission else {
            throw ScreenRecordingError.permissionDenied
        }

        try await performCountdown()
        try await startRecording(captureRect: nil, targetWindow: nil)  // nil = 全屏
    }

    // MARK: - 公共接口：窗口录制
    func startWindowRecording() async throws {
        guard !isRecording else { throw ScreenRecordingError.alreadyRecording }
        guard PermissionManager.shared.hasScreenRecordingPermission else {
            throw ScreenRecordingError.permissionDenied
        }

        // 获取可录制的窗口列表
        let windows = try await getShareableWindows()

        // 截取底图供覆盖层显示
        guard let cgImage = CGDisplayCreateImage(CGMainDisplayID()) else {
            throw ScreenRecordingError.noScreenAvailable
        }
        let scale = NSScreen.main?.backingScaleFactor ?? 1.0
        let bgImage = NSImage(cgImage: cgImage,
                              size: NSSize(width: CGFloat(cgImage.width) / scale,
                                           height: CGFloat(cgImage.height) / scale))

        // 显示专属窗口覆盖层，等待用户选择和配置参数
        let (selectedRect, selectedWindow) = try await showSelectionOverlay(
            background: bgImage,
            windows: windows,
            mode: .windowSelection
        )
        guard let rect = selectedRect else {
            throw ScreenRecordingError.userCancelled
        }

        // 提前显示四角闪烁标识，让用户在倒计时期间明确录制范围
        let indicator = RecordingAreaIndicatorWindow(recordingRect: rect)
        self.areaIndicatorWindow = indicator
        indicator.orderFrontRegardless()

        // 倒计时（如设置）
        do {
            try await performCountdown()
        } catch {
            // 若倒计时被中途取消，及时销毁指示器窗口
            areaIndicatorWindow?.orderOut(nil)
            areaIndicatorWindow = nil
            throw error
        }

        // 开始独立窗口录制
        try await startRecording(captureRect: rect, targetWindow: selectedWindow)
    }

    // MARK: - 暂停/继续录制
    func pauseRecording() {
        guard isRecording && !isPaused else { return }
        isPaused = true
        print("[ScreenRecordingEngine] 录制已暂停")
    }

    func resumeRecording() {
        guard isRecording && isPaused else { return }
        isPaused = false
        needsResumeAdjustment = true
        print("[ScreenRecordingEngine] 录制已继续")
    }

    // MARK: - 停止录制
    func stopRecording() async throws -> URL {
        guard isRecording else { throw ScreenRecordingError.notRecording }

        // 停止流
        try? await stream?.stopCapture()
        stream = nil

        // 停止麦克风采集
        stopMicrophoneCapture()


        // 关闭指示器窗口
        areaIndicatorWindow?.orderOut(nil)
        areaIndicatorWindow = nil

        // 停止时长计时器
        durationTimer?.cancel()
        durationTimer = nil

        // 完成写入并关闭文件描述符
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
        micInput?.markAsFinished()
        await assetWriter?.finishWriting()

        isRecording = false
        isPaused = false
        firstSample = true
        timeOffset = .zero
        lastAppendedPTS = .zero
        needsResumeAdjustment = false

        guard let url = outputURL else {
            throw ScreenRecordingError.saveFailed("输出路径为空")
        }

        // 广播通知，重置状态栏图标
        NotificationCenter.default.post(name: .recordingDidStop, object: nil)

        return url
    }

    // MARK: - 取消录制并删除文件
    func cancelRecording() async throws {
        guard isRecording else { throw ScreenRecordingError.notRecording }
        let url = try await stopRecording()
        try? FileManager.default.removeItem(at: url)
        print("[ScreenRecordingEngine] 录制已取消，已删除临时文件：\(url.path)")
    }

    // MARK: - 私有：专属选区覆盖层展示
    private func showSelectionOverlay(
        background: NSImage,
        windows: [SCWindow] = [],
        mode: RecordSelectionMode = .areaSelection
    ) async throws -> (CGRect?, SCWindow?) {
        return try await withCheckedThrowingContinuation { continuation in
            self.overlayContinuation = continuation

            let overlay = RecordSelectionOverlayWindow(backgroundImage: background, windows: windows, mode: mode)
            self.selectionOverlayWindow = overlay

            overlay.onCancelled = { [weak self] in
                self?.selectionOverlayWindow = nil
                let cont = self?.overlayContinuation
                self?.overlayContinuation = nil
                cont?.resume(returning: (nil, nil))
            }

            overlay.onFinished = { [weak self] rect, window in
                self?.selectionOverlayWindow = nil
                let cont = self?.overlayContinuation
                self?.overlayContinuation = nil
                cont?.resume(returning: (rect, window))
            }

            overlay.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func getShareableWindows() async throws -> [SCWindow] {
        let content = try await SCShareableContent.current
        let appBundleId = Bundle.main.bundleIdentifier
        let filtered = content.windows.filter { window in
            guard window.isOnScreen else { return false }
            guard window.frame.width > 50 && window.frame.height > 50 else { return false }
            guard window.windowLayer == 0 else { return false }
            if let owningApp = window.owningApplication, owningApp.bundleIdentifier == appBundleId {
                return false
            }
            guard let appName = window.owningApplication?.applicationName, !appName.isEmpty else { return false }
            return true
        }
        return filtered
    }

    // MARK: - 私有：倒计时
    private func performCountdown() async throws {
        let seconds = AppSettings.shared.recordTimer
        guard seconds > 0 else { return }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let window = RecordingCountdownWindow(
                seconds: seconds,
                onFinished: {
                    continuation.resume()
                },
                onCancelled: {
                    continuation.resume(throwing: ScreenRecordingError.userCancelled)
                }
            )
            self.countdownWindow = window
            window.makeKeyAndOrderFront(nil)
            window.center()
            NSApp.activate(ignoringOtherApps: true)
        }
        self.countdownWindow = nil
    }


    // MARK: - 私有：核心录制启动
    private func startRecording(captureRect: CGRect?, targetWindow: SCWindow? = nil) async throws {
        let settings = AppSettings.shared

        // ── 准备输出文件路径 ──────────────────────────────────────
        let saveDir = URL(fileURLWithPath: settings.recordSavePath
                            .replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path))
        try FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let fileName = "录屏 \(dateFormatter.string(from: Date()))"
        let ext = settings.recordFormat.lowercased()  // "mov" / "mp4"
        let fileURL = saveDir.appendingPathComponent(fileName).appendingPathExtension(ext)
        self.outputURL = fileURL

        // ── 配置 AVAssetWriter ────────────────────────────────────
        let fileType: AVFileType = settings.recordFormat == "MP4" ? .mp4 : .mov
        let writer = try AVAssetWriter(outputURL: fileURL, fileType: fileType)
        self.assetWriter = writer

        // 计算录制尺寸
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let screenScale = screen.backingScaleFactor
        
        var baseRect = captureRect ?? CGRect(
            origin: .zero,
            size: CGSize(width: screen.frame.width, height: screen.frame.height)
        )
        
        // 如果是从 HUD 中直接选定了特定分辨率的，在此进行二次调整限制
        if settings.recordResolution == "1080p" {
            baseRect.size = CGSize(width: 1920 / screenScale, height: 1080 / screenScale)
        } else if settings.recordResolution == "4K" {
            baseRect.size = CGSize(width: 3840 / screenScale, height: 2160 / screenScale)
        }

        var videoWidth = Int(baseRect.width * screenScale)
        var videoHeight = Int(baseRect.height * screenScale)
        
        // 保证宽高为偶数，防止 AVAssetWriter 报错
        videoWidth = videoWidth - (videoWidth % 2)
        videoHeight = videoHeight - (videoHeight % 2)

        // 视频编码轨设置
        let codecKey = settings.recordCodec == "HEVC" ? AVVideoCodecType.hevc : AVVideoCodecType.h264
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: codecKey,
            AVVideoWidthKey:  videoWidth,
            AVVideoHeightKey: videoHeight,
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true
        self.videoInput = videoInput
        if writer.canAdd(videoInput) { writer.add(videoInput) }

        // 系统音频轨配置
        if settings.recordSystemAudio {
            let systemAudioSettings: [String: Any] = [
                AVFormatIDKey:          kAudioFormatMPEG4AAC,
                AVSampleRateKey:        44100,
                AVNumberOfChannelsKey:  2,
                AVEncoderBitRateKey:    128_000,
            ]
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: systemAudioSettings)
            audioInput.expectsMediaDataInRealTime = true
            self.audioInput = audioInput
            if writer.canAdd(audioInput) { writer.add(audioInput) }
        }

        // 麦克风录制音轨配置
        if settings.recordMicrophone != "无" {
            let micAudioSettings: [String: Any] = [
                AVFormatIDKey:          kAudioFormatMPEG4AAC,
                AVSampleRateKey:        44100,
                AVNumberOfChannelsKey:  2,
                AVEncoderBitRateKey:    128_000,
            ]
            let micInput = AVAssetWriterInput(mediaType: .audio, outputSettings: micAudioSettings)
            micInput.expectsMediaDataInRealTime = true
            self.micInput = micInput
            if writer.canAdd(micInput) { writer.add(micInput) }
        }

        writer.startWriting()

        // ── 配置 SCStream ─────────────────────────────────────────
        let content = try await SCShareableContent.current
        guard let display = content.displays.first else {
            throw ScreenRecordingError.noScreenAvailable
        }

        let filter: SCContentFilter
        if let targetWindow = targetWindow {
            filter = SCContentFilter(desktopIndependentWindow: targetWindow)
        } else {
            filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        }

        let streamConfig = SCStreamConfiguration()
        streamConfig.width  = videoWidth
        streamConfig.height = videoHeight
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(settings.recordFPS))
        streamConfig.queueDepth = 6
        streamConfig.showsCursor = settings.recordHighlightCursor

        // 启用系统声音捕获（macOS 13+）
        if #available(macOS 13.0, *), settings.recordSystemAudio {
            streamConfig.capturesAudio = true
            streamConfig.sampleRate = 44100
            streamConfig.channelCount = 2
        }

        // 如果是选区录制且非窗口录屏，设置裁剪框 sourceRect
        if let rect = captureRect, targetWindow == nil {
            let displayHeight = display.frame.height
            let flippedY = displayHeight - rect.origin.y - rect.height
            streamConfig.sourceRect = CGRect(x: rect.origin.x,
                                             y: flippedY,
                                             width: rect.width,
                                             height: rect.height)
        }

        let captureStream = SCStream(filter: filter, configuration: streamConfig, delegate: self)
        self.stream = captureStream

        try captureStream.addStreamOutput(self, type: .screen,
                                          sampleHandlerQueue: DispatchQueue(label: "com.snapclick.recording.video"))
        
        if settings.recordSystemAudio {
            if #available(macOS 13.0, *) {
                try captureStream.addStreamOutput(self, type: .audio,
                                                  sampleHandlerQueue: DispatchQueue(label: "com.snapclick.recording.audio"))
            }
        }

        // ── 启动音频硬件采集（麦克风） ─────────────────────────────
        startMicrophoneCapture()

        // ── 开启截屏流捕获 ────────────────────────────────────────
        try await captureStream.startCapture()

        // ── 开启区域蓝色闪烁角标指示器（若为选区或窗口模式，且未在倒计时展示） ──
        if let rect = captureRect {
            if self.areaIndicatorWindow == nil {
                let indicator = RecordingAreaIndicatorWindow(recordingRect: rect)
                self.areaIndicatorWindow = indicator
                indicator.orderFrontRegardless()
            }
        }

        // ── 更新内部状态 ─────────────────────────────────────────
        isRecording = true
        isPaused = false
        recordingDuration = 0
        
        durationTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if !self.isPaused {
                    self.recordingDuration += 1
                }
            }


        // 广播录像启动通知，状态栏改为闪烁录制态
        NotificationCenter.default.post(name: .recordingDidStart, object: nil)
    }

    // MARK: - 录制 HUD 浮显控制
    private func showRecordingHUD() {
        let hud = RecordingHUDWindow(
            onPauseResume: { [weak self] in
                guard let self = self else { return }
                if self.isPaused {
                    self.resumeRecording()
                } else {
                    self.pauseRecording()
                }
            },
            onStop: { [weak self] in
                guard let self = self else { return }
                Task {
                    do {
                        let fileURL = try await self.stopRecording()
                        // 在 Finder 中高亮显示输出的文件
                        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                    } catch {
                        print("[ScreenRecordingEngine] 结束录像出错: \(error)")
                    }
                }
            }
        )
        self.hudWindow = hud
        hud.makeKeyAndOrderFront(nil)
    }

    private func closeRecordingHUD() {
        hudWindow?.orderOut(nil)
        hudWindow = nil
    }

    // MARK: - 麦克风录音控制
    private func startMicrophoneCapture() {
        let settings = AppSettings.shared
        guard settings.recordMicrophone != "无" else { return }

        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone, .externalUnknown],
            mediaType: .audio,
            position: .unspecified
        )

        guard let device = session.devices.first(where: { $0.localizedName == settings.recordMicrophone }) else {
            print("[ScreenRecordingEngine] 找不到用户选择的麦克风设备: \(settings.recordMicrophone)")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            let output = AVCaptureAudioDataOutput()

            let micSession = AVCaptureSession()
            if micSession.canAddInput(input) { micSession.addInput(input) }
            if micSession.canAddOutput(output) { micSession.addOutput(output) }

            let queue = DispatchQueue(label: "com.snapclick.recording.mic")
            output.setSampleBufferDelegate(self, queue: queue)

            self.micSession = micSession
            
            DispatchQueue.global(qos: .userInitiated).async {
                micSession.startRunning()
            }
            print("[ScreenRecordingEngine] 成功启动麦克风录制设备: \(device.localizedName)")
        } catch {
            print("[ScreenRecordingEngine] 初始化麦克风捕捉会话失败: \(error)")
        }
    }

    private func stopMicrophoneCapture() {
        micSession?.stopRunning()
        micSession = nil
    }
}

// MARK: - SCStreamDelegate

extension ScreenRecordingEngine: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in
            print("[ScreenRecordingEngine] 截屏捕获流异常终止: \(error)")
            if self.isRecording {
                _ = try? await self.stopRecording()
            }
        }
    }
}

// MARK: - SCStreamOutput（SCKit 视频/系统音频帧采集）

extension ScreenRecordingEngine: SCStreamOutput {
    nonisolated func stream(_ stream: SCStream,
                             didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                             of outputType: SCStreamOutputType) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }

        Task { @MainActor in
            guard self.isRecording && !self.isPaused else { return }
            guard let writer = self.assetWriter else { return }

            // 第一帧到来时启动写入 Session
            if self.firstSample {
                self.firstSample = false
                let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                writer.startSession(atSourceTime: pts)
                self.recordingStartTime = pts
            }

            switch outputType {
            case .screen:
                if let videoInput = self.videoInput, videoInput.isReadyForMoreMediaData {
                    let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    
                    // 恢复录制时，动态计算并补偿暂停期间消耗的帧差时间偏移
                    if self.needsResumeAdjustment {
                        self.needsResumeAdjustment = false
                        if self.lastAppendedPTS != .zero {
                            let gap = pts - self.lastAppendedPTS
                            self.timeOffset = self.timeOffset + gap
                        }
                    }
                    
                    let adjustedPTS = pts - self.timeOffset
                    self.lastAppendedPTS = adjustedPTS
                    
                    if self.timeOffset != .zero {
                        if let adjustedBuffer = sampleBuffer.withTimingOffset(self.timeOffset) {
                            videoInput.append(adjustedBuffer)
                        }
                    } else {
                        videoInput.append(sampleBuffer)
                    }
                }
            default:
                // .audio 仅在 macOS 13+ 可用
                if #available(macOS 13.0, *) {
                    if case .audio = outputType,
                       let audioInput = self.audioInput,
                       audioInput.isReadyForMoreMediaData {
                        if self.timeOffset != .zero {
                            if let adjustedBuffer = sampleBuffer.withTimingOffset(self.timeOffset) {
                                audioInput.append(adjustedBuffer)
                            }
                        } else {
                            audioInput.append(sampleBuffer)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - AVCaptureAudioDataOutputSampleBufferDelegate（麦克风音频帧采集）

extension ScreenRecordingEngine: AVCaptureAudioDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput,
                                   didOutput sampleBuffer: CMSampleBuffer,
                                   from connection: AVCaptureConnection) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
        
        Task { @MainActor in
            guard self.isRecording && !self.isPaused else { return }
            guard let writer = self.assetWriter else { return }
            
            // 如果第一帧是从麦克风先到来，也需支持会话初始化
            if self.firstSample {
                self.firstSample = false
                let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                writer.startSession(atSourceTime: pts)
                self.recordingStartTime = pts
            }
            
            if let micInput = self.micInput, micInput.isReadyForMoreMediaData {
                if self.timeOffset != .zero {
                    if let adjustedBuffer = sampleBuffer.withTimingOffset(self.timeOffset) {
                        micInput.append(adjustedBuffer)
                    }
                } else {
                    micInput.append(sampleBuffer)
                }
            }
        }
    }
}

// MARK: - CMSampleBuffer 帧播放时间修正扩展
extension CMSampleBuffer {
    func withTimingOffset(_ offset: CMTime) -> CMSampleBuffer? {
        var count: CMItemCount = 0
        CMSampleBufferGetSampleTimingInfoArray(self, entryCount: 0, arrayToFill: nil, entriesNeededOut: &count)
        guard count > 0 else { return nil }
        
        var info = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: .invalid, decodeTimeStamp: .invalid), count: count)
        CMSampleBufferGetSampleTimingInfoArray(self, entryCount: count, arrayToFill: &info, entriesNeededOut: &count)
        
        for i in 0..<count {
            if info[i].presentationTimeStamp.isValid {
                info[i].presentationTimeStamp = info[i].presentationTimeStamp - offset
            }
            if info[i].decodeTimeStamp.isValid {
                info[i].decodeTimeStamp = info[i].decodeTimeStamp - offset
            }
        }
        
        var adjustedBuffer: CMSampleBuffer?
        let status = CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: self,
            sampleTimingEntryCount: count,
            sampleTimingArray: &info,
            sampleBufferOut: &adjustedBuffer
        )
        
        return status == noErr ? adjustedBuffer : nil
    }
}

// MARK: - Notification 扩展
public extension Notification.Name {
    static let recordingDidStart   = Notification.Name("SnapClickRecordingDidStart")
    static let recordingDidStop    = Notification.Name("SnapClickRecordingDidStop")
    static let recordingCountdown  = Notification.Name("SnapClickRecordingCountdown")
}

