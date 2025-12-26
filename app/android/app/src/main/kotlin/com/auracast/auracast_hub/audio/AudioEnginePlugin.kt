package com.auracast.auracast_hub.audio

import android.content.Context
import android.media.*
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Android implementation of the SpatialSync audio engine.
 * Provides low-latency audio playback (client mode) and file capture (host mode).
 */
class AudioEnginePlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    // Audio playback (Client mode)
    private var audioTrack: AudioTrack? = null
    private var playbackExecutor: ExecutorService? = null

    // Audio capture (Host mode)
    private var mediaExtractor: MediaExtractor? = null
    private var mediaCodec: MediaCodec? = null
    private var captureExecutor: ExecutorService? = null
    private val isCapturing = AtomicBoolean(false)

    // Configuration
    private var sampleRate = 48000
    private var channelCount = 2
    private var bufferSizeMs = 100

    // State
    private var isInitialized = false
    private var isPlaying = false

    // Timing
    private var playbackStartTimeUs: Long = 0
    private var framesWritten: Long = 0

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext

        methodChannel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            "com.spatialsync.audio/method"
        )
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "com.spatialsync.audio/events"
        )
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        dispose()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> initialize(call, result)
            "startCapture" -> startCapture(call, result)
            "stopCapture" -> stopCapture(result)
            "startPlayback" -> startPlayback(result)
            "stopPlayback" -> stopPlayback(result)
            "queueAudio" -> queueAudio(call, result)
            "setChannelVolume" -> setChannelVolume(call, result)
            "getPlaybackPositionUs" -> getPlaybackPositionUs(result)
            "getOutputLatencyMs" -> getOutputLatencyMs(result)
            "dispose" -> {
                dispose()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun initialize(call: MethodCall, result: Result) {
        try {
            sampleRate = call.argument<Int>("sampleRate") ?: 48000
            channelCount = call.argument<Int>("channelCount") ?: 2
            bufferSizeMs = call.argument<Int>("bufferSizeMs") ?: 100

            // Initialize AudioTrack for playback
            initializeAudioTrack()

            // Initialize executors
            playbackExecutor = Executors.newSingleThreadExecutor()
            captureExecutor = Executors.newSingleThreadExecutor()

            isInitialized = true
            result.success(null)
        } catch (e: Exception) {
            result.error("INIT_ERROR", "Failed to initialize audio engine: ${e.message}", null)
        }
    }

    private fun initializeAudioTrack() {
        val channelConfig = if (channelCount == 2) {
            AudioFormat.CHANNEL_OUT_STEREO
        } else {
            AudioFormat.CHANNEL_OUT_MONO
        }

        val minBufferSize = AudioTrack.getMinBufferSize(
            sampleRate,
            channelConfig,
            AudioFormat.ENCODING_PCM_16BIT
        )

        // Use larger buffer for stability
        val bufferSize = maxOf(
            minBufferSize * 2,
            sampleRate * channelCount * 2 * bufferSizeMs / 1000
        )

        audioTrack = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(sampleRate)
                    .setChannelMask(channelConfig)
                    .build()
            )
            .setBufferSizeInBytes(bufferSize)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
            .build()
    }

    private fun startCapture(call: MethodCall, result: Result) {
        if (!isInitialized) {
            result.error("NOT_INIT", "Audio engine not initialized", null)
            return
        }

        val sourceType = call.argument<String>("sourceType") ?: "file"
        val sourcePath = call.argument<String>("sourcePath")

        when (sourceType) {
            "file" -> {
                if (sourcePath == null) {
                    result.error("INVALID_ARGS", "Source path required for file capture", null)
                    return
                }
                startFileCapture(sourcePath, result)
            }
            "microphone" -> {
                result.error("NOT_IMPLEMENTED", "Microphone capture not yet implemented", null)
            }
            else -> {
                result.error("INVALID_ARGS", "Unknown source type: $sourceType", null)
            }
        }
    }

    private fun startFileCapture(filePath: String, result: Result) {
        try {
            val file = File(filePath)
            if (!file.exists()) {
                result.error("FILE_NOT_FOUND", "Audio file not found: $filePath", null)
                return
            }

            isCapturing.set(true)

            captureExecutor?.execute {
                try {
                    decodeAndStreamAudio(filePath)
                } catch (e: Exception) {
                    mainHandler.post {
                        sendEvent("playbackError", mapOf("error" to e.message))
                    }
                }
            }

            result.success(null)
        } catch (e: Exception) {
            result.error("CAPTURE_ERROR", "Failed to start capture: ${e.message}", null)
        }
    }

    private fun decodeAndStreamAudio(filePath: String) {
        var extractor: MediaExtractor? = null
        var codec: MediaCodec? = null

        try {
            extractor = MediaExtractor()
            extractor.setDataSource(filePath)

            // Find audio track
            var audioTrackIndex = -1
            var audioFormat: MediaFormat? = null

            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME)
                if (mime?.startsWith("audio/") == true) {
                    audioTrackIndex = i
                    audioFormat = format
                    break
                }
            }

            if (audioTrackIndex < 0 || audioFormat == null) {
                mainHandler.post {
                    sendEvent("playbackError", mapOf("error" to "No audio track found"))
                }
                return
            }

            extractor.selectTrack(audioTrackIndex)

            // Get source format info
            val sourceSampleRate = audioFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            val sourceChannels = audioFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)

            // Create decoder
            val mime = audioFormat.getString(MediaFormat.KEY_MIME)!!
            codec = MediaCodec.createDecoderByType(mime)
            codec.configure(audioFormat, null, null, 0)
            codec.start()

            val bufferInfo = MediaCodec.BufferInfo()
            var inputDone = false
            var outputDone = false

            // Calculate frame size for output (16-bit PCM, target channels)
            val bytesPerSample = 2
            val targetFrameSize = channelCount * bytesPerSample

            // Buffer for resampling/channel conversion if needed
            val outputBuffer = ByteBuffer.allocate(sampleRate * channelCount * bytesPerSample / 10) // 100ms buffer
            outputBuffer.order(ByteOrder.LITTLE_ENDIAN)

            while (!outputDone && isCapturing.get()) {
                // Feed input
                if (!inputDone) {
                    val inputBufferIndex = codec.dequeueInputBuffer(10000)
                    if (inputBufferIndex >= 0) {
                        val inputBuffer = codec.getInputBuffer(inputBufferIndex)!!
                        val sampleSize = extractor.readSampleData(inputBuffer, 0)

                        if (sampleSize < 0) {
                            codec.queueInputBuffer(
                                inputBufferIndex, 0, 0, 0,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM
                            )
                            inputDone = true
                        } else {
                            codec.queueInputBuffer(
                                inputBufferIndex, 0, sampleSize,
                                extractor.sampleTime, 0
                            )
                            extractor.advance()
                        }
                    }
                }

                // Get output
                val outputBufferIndex = codec.dequeueOutputBuffer(bufferInfo, 10000)
                if (outputBufferIndex >= 0) {
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        outputDone = true
                    }

                    val decodedBuffer = codec.getOutputBuffer(outputBufferIndex)
                    if (decodedBuffer != null && bufferInfo.size > 0) {
                        // Read decoded PCM data
                        val pcmData = ByteArray(bufferInfo.size)
                        decodedBuffer.get(pcmData)
                        decodedBuffer.clear()

                        // Convert to target format (48kHz, stereo, 16-bit) if needed
                        val convertedData = convertAudioFormat(
                            pcmData, sourceSampleRate, sourceChannels,
                            sampleRate, channelCount
                        )

                        // Send to Flutter via event channel
                        val timestamp = System.nanoTime() / 1000 // microseconds
                        mainHandler.post {
                            sendEvent("audioData", mapOf(
                                "data" to convertedData,
                                "timestamp" to timestamp,
                                "channels" to channelCount
                            ))
                        }
                    }

                    codec.releaseOutputBuffer(outputBufferIndex, false)
                }
            }

            // Notify completion
            mainHandler.post {
                sendEvent("playbackComplete", null)
            }

        } catch (e: Exception) {
            mainHandler.post {
                sendEvent("playbackError", mapOf("error" to e.message))
            }
        } finally {
            codec?.stop()
            codec?.release()
            extractor?.release()
            isCapturing.set(false)
        }
    }

    private fun convertAudioFormat(
        input: ByteArray,
        srcRate: Int, srcChannels: Int,
        dstRate: Int, dstChannels: Int
    ): ByteArray {
        // If formats match, return as-is
        if (srcRate == dstRate && srcChannels == dstChannels) {
            return input
        }

        val bytesPerSample = 2 // 16-bit
        val srcFrameSize = srcChannels * bytesPerSample
        val dstFrameSize = dstChannels * bytesPerSample
        val srcFrameCount = input.size / srcFrameSize

        // Calculate output frame count after resampling
        val dstFrameCount = (srcFrameCount.toLong() * dstRate / srcRate).toInt()
        val output = ByteArray(dstFrameCount * dstFrameSize)

        val srcBuffer = ByteBuffer.wrap(input).order(ByteOrder.LITTLE_ENDIAN)
        val dstBuffer = ByteBuffer.wrap(output).order(ByteOrder.LITTLE_ENDIAN)

        for (dstFrame in 0 until dstFrameCount) {
            // Simple linear interpolation for resampling
            val srcPos = dstFrame.toDouble() * srcRate / dstRate
            val srcFrame = srcPos.toInt().coerceIn(0, srcFrameCount - 1)
            val srcOffset = srcFrame * srcFrameSize

            // Read source samples
            val leftSample = if (srcOffset + 1 < input.size) {
                srcBuffer.getShort(srcOffset)
            } else 0

            val rightSample = if (srcChannels >= 2 && srcOffset + 3 < input.size) {
                srcBuffer.getShort(srcOffset + 2)
            } else {
                leftSample // Mono to stereo: duplicate
            }

            // Write destination samples
            val dstOffset = dstFrame * dstFrameSize
            if (dstChannels >= 1) {
                dstBuffer.putShort(dstOffset, leftSample)
            }
            if (dstChannels >= 2) {
                dstBuffer.putShort(dstOffset + 2, rightSample)
            }
        }

        return output
    }

    private fun stopCapture(result: Result) {
        isCapturing.set(false)
        result.success(null)
    }

    private fun startPlayback(result: Result) {
        if (!isInitialized) {
            result.error("NOT_INIT", "Audio engine not initialized", null)
            return
        }

        try {
            audioTrack?.play()
            isPlaying = true
            playbackStartTimeUs = System.nanoTime() / 1000
            framesWritten = 0
            result.success(null)
        } catch (e: Exception) {
            result.error("PLAYBACK_ERROR", "Failed to start playback: ${e.message}", null)
        }
    }

    private fun stopPlayback(result: Result) {
        try {
            audioTrack?.pause()
            audioTrack?.flush()
            isPlaying = false
            result.success(null)
        } catch (e: Exception) {
            result.error("PLAYBACK_ERROR", "Failed to stop playback: ${e.message}", null)
        }
    }

    private fun queueAudio(call: MethodCall, result: Result) {
        if (!isInitialized) {
            result.error("NOT_INIT", "Audio engine not initialized", null)
            return
        }

        val data = call.argument<ByteArray>("data")
        if (data == null) {
            result.error("INVALID_ARGS", "Audio data required", null)
            return
        }

        // Write audio data to AudioTrack
        playbackExecutor?.execute {
            try {
                val track = audioTrack
                if (track != null && isPlaying) {
                    val written = track.write(data, 0, data.size)
                    if (written > 0) {
                        framesWritten += written / (channelCount * 2) // 16-bit samples
                    }
                }
            } catch (e: Exception) {
                // Log error but don't crash
            }
        }

        result.success(null)
    }

    private fun setChannelVolume(call: MethodCall, result: Result) {
        val volume = call.argument<Double>("volume") ?: 1.0

        try {
            audioTrack?.setVolume(volume.toFloat())
            result.success(null)
        } catch (e: Exception) {
            result.error("VOLUME_ERROR", "Failed to set volume: ${e.message}", null)
        }
    }

    private fun getPlaybackPositionUs(result: Result) {
        val track = audioTrack
        if (track == null) {
            result.success(0L)
            return
        }

        try {
            val position = track.playbackHeadPosition
            val positionUs = position.toLong() * 1_000_000 / sampleRate
            result.success(positionUs)
        } catch (e: Exception) {
            result.success(0L)
        }
    }

    private fun getOutputLatencyMs(result: Result) {
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val framesPerBuffer = audioManager.getProperty(AudioManager.PROPERTY_OUTPUT_FRAMES_PER_BUFFER)?.toIntOrNull() ?: 256
            val deviceSampleRate = audioManager.getProperty(AudioManager.PROPERTY_OUTPUT_SAMPLE_RATE)?.toIntOrNull() ?: 48000

            // Estimate latency based on buffer size
            val latencyMs = (framesPerBuffer * 1000 / deviceSampleRate) + 20 // Add some overhead
            result.success(latencyMs)
        } catch (e: Exception) {
            result.success(50) // Default estimate
        }
    }

    private fun dispose() {
        isCapturing.set(false)
        isPlaying = false
        isInitialized = false

        try {
            audioTrack?.stop()
            audioTrack?.release()
            audioTrack = null
        } catch (e: Exception) {
            // Ignore
        }

        try {
            mediaCodec?.stop()
            mediaCodec?.release()
            mediaCodec = null
        } catch (e: Exception) {
            // Ignore
        }

        try {
            mediaExtractor?.release()
            mediaExtractor = null
        } catch (e: Exception) {
            // Ignore
        }

        playbackExecutor?.shutdown()
        playbackExecutor = null

        captureExecutor?.shutdown()
        captureExecutor = null
    }

    private fun sendEvent(type: String, data: Map<String, Any?>?) {
        val event = mutableMapOf<String, Any?>("type" to type)
        if (data != null) {
            event.putAll(data)
        }
        eventSink?.success(event)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}
