import Flutter
import AVFoundation

/// Flutter plugin for audio engine operations using AVAudioEngine.
class AudioEnginePlugin: NSObject {
    private let methodChannel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel
    private var eventSink: FlutterEventSink?

    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var mixerNode: AVAudioMixerNode?
    private var audioFile: AVAudioFile?

    private var sampleRate: Double = 48000
    private var channelCount: AVAudioChannelCount = 2
    private var bufferSizeMs: Int = 100

    private var isInitialized = false
    private var isPlaying = false

    // Jitter buffer for synchronized playback
    private var audioBuffer: [(data: AVAudioPCMBuffer, playTime: Int64)] = []
    private let bufferLock = NSLock()

    init(messenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(
            name: "com.spatialsync.audio/method",
            binaryMessenger: messenger
        )
        eventChannel = FlutterEventChannel(
            name: "com.spatialsync.audio/events",
            binaryMessenger: messenger
        )

        super.init()

        methodChannel.setMethodCallHandler(handleMethodCall)
        eventChannel.setStreamHandler(self)
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            initialize(call: call, result: result)
        case "startCapture":
            startCapture(call: call, result: result)
        case "stopCapture":
            stopCapture(result: result)
        case "startPlayback":
            startPlayback(result: result)
        case "stopPlayback":
            stopPlayback(result: result)
        case "queueAudio":
            queueAudio(call: call, result: result)
        case "setChannelVolume":
            setChannelVolume(call: call, result: result)
        case "getPlaybackPositionUs":
            result(getPlaybackPositionUs())
        case "getOutputLatencyMs":
            result(getOutputLatencyMs())
        case "dispose":
            dispose(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Initialization

    private func initialize(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }

        sampleRate = Double(args["sampleRate"] as? Int ?? 48000)
        channelCount = AVAudioChannelCount(args["channelCount"] as? Int ?? 2)
        bufferSizeMs = args["bufferSizeMs"] as? Int ?? 100

        do {
            try setupAudioSession()
            try setupAudioEngine()
            isInitialized = true
            result(nil)
        } catch {
            result(FlutterError(code: "INIT_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func setupAudioSession() throws {
        let session = AVAudioSession.sharedInstance()

        // Set preferred buffer duration for low latency
        let bufferDuration = TimeInterval(bufferSizeMs) / 1000.0
        try session.setPreferredIOBufferDuration(bufferDuration)

        // Set category for playback
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true)
    }

    private func setupAudioEngine() throws {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        mixerNode = audioEngine?.mainMixerNode

        guard let engine = audioEngine, let player = playerNode else {
            throw NSError(domain: "AudioEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio engine"])
        }

        engine.attach(player)

        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: channelCount
        )!

        engine.connect(player, to: engine.mainMixerNode, format: format)

        try engine.start()
    }

    // MARK: - Capture (for host mode)

    private func startCapture(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isInitialized else {
            result(FlutterError(code: "NOT_INIT", message: "Audio engine not initialized", details: nil))
            return
        }

        guard let args = call.arguments as? [String: Any],
              let sourceType = args["sourceType"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }

        switch sourceType {
        case "file":
            guard let path = args["sourcePath"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "File path required", details: nil))
                return
            }
            startFileCapture(path: path, result: result)
        case "microphone":
            startMicrophoneCapture(result: result)
        default:
            result(FlutterError(code: "UNSUPPORTED", message: "Unsupported source type", details: nil))
        }
    }

    private func startFileCapture(path: String, result: @escaping FlutterResult) {
        do {
            let url = URL(fileURLWithPath: path)
            audioFile = try AVAudioFile(forReading: url)

            guard let file = audioFile, let player = playerNode, let engine = audioEngine else {
                result(FlutterError(code: "FILE_ERROR", message: "Failed to open file", details: nil))
                return
            }

            // Use the file's processing format for connection
            let fileFormat = file.processingFormat

            // Reconnect player with file's format to avoid format mismatch
            engine.disconnectNodeOutput(player)
            engine.connect(player, to: engine.mainMixerNode, format: fileFormat)

            // Install tap with nil format to use the node's current output format
            let frameCapacity = AVAudioFrameCount(fileFormat.sampleRate * Double(bufferSizeMs) / 1000.0)

            player.installTap(onBus: 0, bufferSize: frameCapacity, format: nil) { [weak self] buffer, time in
                self?.handleCapturedAudio(buffer: buffer, time: time)
            }

            player.scheduleFile(file, at: nil) { [weak self] in
                self?.sendEvent(type: "playbackComplete", data: nil)
            }

            result(nil)
        } catch {
            result(FlutterError(code: "FILE_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func startMicrophoneCapture(result: @escaping FlutterResult) {
        guard let engine = audioEngine else {
            result(FlutterError(code: "NOT_INIT", message: "Audio engine not initialized", details: nil))
            return
        }

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        let frameCapacity = AVAudioFrameCount(format.sampleRate * Double(bufferSizeMs) / 1000.0)

        inputNode.installTap(onBus: 0, bufferSize: frameCapacity, format: format) { [weak self] buffer, time in
            self?.handleCapturedAudio(buffer: buffer, time: time)
        }

        result(nil)
    }

    private func handleCapturedAudio(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        // Convert to interleaved PCM data
        guard let data = bufferToData(buffer: buffer) else { return }

        let timestamp = Int64(time.sampleTime) * 1_000_000 / Int64(sampleRate)

        sendEvent(type: "audioData", data: [
            "data": FlutterStandardTypedData(bytes: data),
            "timestamp": timestamp,
            "channels": channelCount
        ])
    }

    private func bufferToData(buffer: AVAudioPCMBuffer) -> Data? {
        guard let floatData = buffer.floatChannelData else { return nil }

        let frameLength = Int(buffer.frameLength)
        let channels = Int(buffer.format.channelCount)

        var data = Data(capacity: frameLength * channels * 2) // 16-bit

        for frame in 0..<frameLength {
            for channel in 0..<channels {
                let sample = floatData[channel][frame]
                var int16Sample = Int16(max(-32768, min(32767, sample * 32767)))
                data.append(contentsOf: withUnsafeBytes(of: &int16Sample) { Array($0) })
            }
        }

        return data
    }

    private func stopCapture(result: @escaping FlutterResult) {
        playerNode?.removeTap(onBus: 0)
        audioEngine?.inputNode.removeTap(onBus: 0)
        result(nil)
    }

    // MARK: - Playback (for client mode)

    private func startPlayback(result: @escaping FlutterResult) {
        guard isInitialized else {
            result(FlutterError(code: "NOT_INIT", message: "Audio engine not initialized", details: nil))
            return
        }

        playerNode?.play()
        isPlaying = true
        result(nil)
    }

    private func stopPlayback(result: @escaping FlutterResult) {
        playerNode?.stop()
        isPlaying = false
        result(nil)
    }

    private func queueAudio(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isInitialized, let player = playerNode else {
            result(FlutterError(code: "NOT_INIT", message: "Audio engine not initialized", details: nil))
            return
        }

        guard let args = call.arguments as? [String: Any],
              let data = args["data"] as? FlutterStandardTypedData else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }

        // Convert data to AVAudioPCMBuffer
        guard let buffer = dataToBuffer(data: data.data) else {
            result(FlutterError(code: "BUFFER_ERROR", message: "Failed to create buffer", details: nil))
            return
        }

        // Flutter's AudioBuffer already handles timing via getReadyPackets()
        // Just queue the buffer for immediate sequential playback
        // The AVAudioPlayerNode will play buffers in order as they're scheduled
        player.scheduleBuffer(buffer, completionHandler: nil)

        result(nil)
    }

    private func dataToBuffer(data: Data) -> AVAudioPCMBuffer? {
        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: channelCount
        )!

        let frameCount = AVAudioFrameCount(data.count / (Int(channelCount) * 2)) // 16-bit samples

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }

        buffer.frameLength = frameCount

        guard let floatData = buffer.floatChannelData else { return nil }

        data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            let int16Ptr = bytes.bindMemory(to: Int16.self)

            for frame in 0..<Int(frameCount) {
                for channel in 0..<Int(channelCount) {
                    let index = frame * Int(channelCount) + channel
                    floatData[channel][frame] = Float(int16Ptr[index]) / 32767.0
                }
            }
        }

        return buffer
    }

    // MARK: - Volume Control

    private func setChannelVolume(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let volume = args["volume"] as? Double else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }

        mixerNode?.outputVolume = Float(volume)
        result(nil)
    }

    // MARK: - Position & Latency

    private func getCurrentTimeUs() -> Int64 {
        return Int64(Date().timeIntervalSince1970 * 1_000_000)
    }

    private func getPlaybackPositionUs() -> Int64 {
        guard let player = playerNode,
              let lastRenderTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: lastRenderTime) else {
            return 0
        }

        return Int64(Double(playerTime.sampleTime) / sampleRate * 1_000_000)
    }

    private func getOutputLatencyMs() -> Int {
        let session = AVAudioSession.sharedInstance()
        let latency = session.outputLatency + session.ioBufferDuration
        return Int(latency * 1000)
    }

    // MARK: - Events

    private func sendEvent(type: String, data: Any?) {
        var event: [String: Any] = ["type": type]
        if let data = data as? [String: Any] {
            event.merge(data) { _, new in new }
        }

        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(event)
        }
    }

    // MARK: - Cleanup

    private func dispose(result: @escaping FlutterResult) {
        playerNode?.stop()
        audioEngine?.stop()

        playerNode = nil
        mixerNode = nil
        audioEngine = nil
        audioFile = nil

        isInitialized = false
        isPlaying = false

        result(nil)
    }
}

// MARK: - FlutterStreamHandler

extension AudioEnginePlugin: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
