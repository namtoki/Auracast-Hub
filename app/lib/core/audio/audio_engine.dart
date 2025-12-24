import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../../models/models.dart';

/// Platform channel wrapper for native audio engine.
/// On iOS, uses AVAudioEngine for low-latency playback.
class AudioEngine {
  static const MethodChannel _channel =
      MethodChannel('com.spatialsync.audio/method');
  static const EventChannel _eventChannel =
      EventChannel('com.spatialsync.audio/events');

  StreamSubscription? _eventSubscription;
  final _audioDataController = StreamController<AudioFrame>.broadcast();

  bool _isInitialized = false;
  bool _isPlaying = false;

  /// Stream of captured audio frames (for host mode).
  Stream<AudioFrame> get audioFrameStream => _audioDataController.stream;

  /// Whether the audio engine is initialized.
  bool get isInitialized => _isInitialized;

  /// Whether audio is currently playing.
  bool get isPlaying => _isPlaying;

  /// Initialize the audio engine.
  Future<void> initialize({
    int sampleRate = 48000,
    int channelCount = 2,
    int bufferSizeMs = 100,
  }) async {
    try {
      await _channel.invokeMethod('initialize', {
        'sampleRate': sampleRate,
        'channelCount': channelCount,
        'bufferSizeMs': bufferSizeMs,
      });
      _isInitialized = true;

      // Listen for audio events
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        _handleAudioEvent,
        onError: (error) {
          // Handle errors
        },
      );
    } on PlatformException catch (e) {
      throw AudioEngineException('Failed to initialize: ${e.message}');
    }
  }

  void _handleAudioEvent(dynamic event) {
    if (event is! Map) return;

    final type = event['type'] as String?;
    switch (type) {
      case 'audioData':
        final data = event['data'] as Uint8List?;
        final timestamp = event['timestamp'] as int?;
        final channels = event['channels'] as int? ?? 2;

        if (data != null && timestamp != null) {
          _audioDataController.add(AudioFrame(
            data: data,
            timestampUs: timestamp,
            channelCount: channels,
          ));
        }
      case 'playbackError':
        // Handle playback error
        break;
    }
  }

  /// Start capturing audio from file or microphone.
  Future<void> startCapture({required AudioSource source}) async {
    _ensureInitialized();

    try {
      await _channel.invokeMethod('startCapture', {
        'sourceType': source.type.name,
        'sourcePath': source.path,
      });
    } on PlatformException catch (e) {
      throw AudioEngineException('Failed to start capture: ${e.message}');
    }
  }

  /// Stop capturing audio.
  Future<void> stopCapture() async {
    try {
      await _channel.invokeMethod('stopCapture');
    } on PlatformException catch (e) {
      throw AudioEngineException('Failed to stop capture: ${e.message}');
    }
  }

  /// Start playback.
  Future<void> startPlayback() async {
    _ensureInitialized();

    try {
      await _channel.invokeMethod('startPlayback');
      _isPlaying = true;
    } on PlatformException catch (e) {
      throw AudioEngineException('Failed to start playback: ${e.message}');
    }
  }

  /// Stop playback.
  Future<void> stopPlayback() async {
    try {
      await _channel.invokeMethod('stopPlayback');
      _isPlaying = false;
    } on PlatformException catch (e) {
      throw AudioEngineException('Failed to stop playback: ${e.message}');
    }
  }

  /// Queue audio data for playback at specific time.
  Future<void> queueAudio({
    required Uint8List data,
    required int playTimeUs,
    required int channelMask,
  }) async {
    _ensureInitialized();

    try {
      await _channel.invokeMethod('queueAudio', {
        'data': data,
        'playTimeUs': playTimeUs,
        'channelMask': channelMask,
      });
    } on PlatformException catch (e) {
      throw AudioEngineException('Failed to queue audio: ${e.message}');
    }
  }

  /// Set volume for a specific channel.
  Future<void> setChannelVolume({
    required AudioChannel channel,
    required double volume,
  }) async {
    try {
      await _channel.invokeMethod('setChannelVolume', {
        'channelMask': channel.maskBit,
        'volume': volume.clamp(0.0, 1.0),
      });
    } on PlatformException catch (e) {
      throw AudioEngineException('Failed to set volume: ${e.message}');
    }
  }

  /// Get current playback position in microseconds.
  Future<int> getPlaybackPositionUs() async {
    try {
      final result = await _channel.invokeMethod('getPlaybackPositionUs');
      return result as int? ?? 0;
    } on PlatformException {
      return 0;
    }
  }

  /// Get estimated output latency in milliseconds.
  Future<int> getOutputLatencyMs() async {
    try {
      final result = await _channel.invokeMethod('getOutputLatencyMs');
      return result as int? ?? 0;
    } on PlatformException {
      return 0;
    }
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw AudioEngineException('Audio engine not initialized');
    }
  }

  /// Dispose the audio engine.
  Future<void> dispose() async {
    _eventSubscription?.cancel();
    _audioDataController.close();

    try {
      await _channel.invokeMethod('dispose');
    } catch (_) {}

    _isInitialized = false;
    _isPlaying = false;
  }
}

/// Audio frame captured from the audio engine.
class AudioFrame {
  final Uint8List data;
  final int timestampUs;
  final int channelCount;

  const AudioFrame({
    required this.data,
    required this.timestampUs,
    required this.channelCount,
  });
}

/// Audio source configuration.
class AudioSource {
  final AudioSourceType type;
  final String? path;

  const AudioSource.file(String filePath)
      : type = AudioSourceType.file,
        path = filePath;

  const AudioSource.microphone()
      : type = AudioSourceType.microphone,
        path = null;

  const AudioSource.systemAudio()
      : type = AudioSourceType.systemAudio,
        path = null;
}

enum AudioSourceType {
  file,
  microphone,
  systemAudio,
}

class AudioEngineException implements Exception {
  final String message;
  const AudioEngineException(this.message);

  @override
  String toString() => 'AudioEngineException: $message';
}
