import 'dart:async';
import 'dart:typed_data';

import '../../models/models.dart';
import 'audio_packet.dart';
import 'audio_streamer.dart';
import 'discovery_service.dart';
import 'time_sync.dart';

/// Main protocol coordinator for synchronized audio playback.
class SyncProtocol {
  final TimeSync _timeSync;
  final AudioStreamer _audioStreamer;
  final DiscoveryService _discoveryService;

  Session? _currentSession;
  DeviceInfo? _localDevice;
  bool _isHost = false;

  final _sessionController = StreamController<Session?>.broadcast();
  final _packetController = StreamController<AudioPacket>.broadcast();

  SyncProtocol()
      : _timeSync = TimeSync(),
        _audioStreamer = AudioStreamer(timeSync: TimeSync()),
        _discoveryService = DiscoveryService();

  /// Stream of session updates.
  Stream<Session?> get sessionStream => _sessionController.stream;

  /// Stream of received audio packets (for clients).
  Stream<AudioPacket> get packetStream => _packetController.stream;

  /// Current session.
  Session? get currentSession => _currentSession;

  /// Whether this device is the host.
  bool get isHost => _isHost;

  /// Time sync instance.
  TimeSync get timeSync => _timeSync;

  /// Discovery service instance.
  DiscoveryService get discoveryService => _discoveryService;

  /// Initialize with local device info.
  void initialize(DeviceInfo device) {
    _localDevice = device;
  }

  /// Create a new session as host.
  Future<Session> createSession({String? name}) async {
    if (_localDevice == null) {
      throw StateError('Local device not initialized');
    }

    _isHost = true;

    // Start host services
    await _timeSync.startAsHost();
    await _audioStreamer.startHost();

    // Create session
    final session = Session(
      id: DateTime.now().millisecondsSinceEpoch.toRadixString(36),
      hostDeviceId: _localDevice!.id,
      name: name ?? '${_localDevice!.name}\'s Session',
      createdAt: DateTime.now(),
      state: SessionState.idle,
      devices: [_localDevice!.copyWith(isHost: true)],
    );

    _currentSession = session;
    _sessionController.add(session);

    // Start advertising
    await _discoveryService.startAdvertising(
      sessionId: session.id,
      sessionName: session.name!,
      hostDevice: _localDevice!,
    );

    return session;
  }

  /// Join an existing session as client.
  Future<void> joinSession(DiscoveredHost host) async {
    if (_localDevice == null) {
      throw StateError('Local device not initialized');
    }

    _isHost = false;

    // Start client services
    await _timeSync.startAsClient(host.ipAddress);
    await _audioStreamer.startClient(
      host.ipAddress,
      (packet) => _packetController.add(packet),
    );

    // Create local session representation
    _currentSession = Session(
      id: host.sessionId,
      hostDeviceId: host.hostDevice.id,
      name: host.sessionName,
      createdAt: DateTime.now(),
      state: SessionState.connecting,
      devices: [
        host.hostDevice.copyWith(isHost: true),
        _localDevice!.copyWith(
          connectionState: DeviceConnectionState.connecting,
        ),
      ],
    );

    _sessionController.add(_currentSession);
  }

  /// Start discovering available sessions.
  Future<void> startDiscovery() async {
    await _discoveryService.startDiscovery();
  }

  /// Stop discovering sessions.
  Future<void> stopDiscovery() async {
    await _discoveryService.stop();
  }

  /// Update channel assignment for a device.
  void updateChannelAssignment(ChannelAssignment assignment) {
    if (_currentSession == null) return;

    final assignments =
        List<ChannelAssignment>.from(_currentSession!.channelAssignments);
    final existingIndex =
        assignments.indexWhere((a) => a.deviceId == assignment.deviceId);

    if (existingIndex >= 0) {
      assignments[existingIndex] = assignment;
    } else {
      assignments.add(assignment);
    }

    _currentSession = _currentSession!.copyWith(
      channelAssignments: assignments,
    );
    _sessionController.add(_currentSession);
  }

  /// Start playback.
  void startPlayback() {
    if (_currentSession == null) return;

    _currentSession = _currentSession!.copyWith(state: SessionState.playing);
    _sessionController.add(_currentSession);
  }

  /// Pause playback.
  void pausePlayback() {
    if (_currentSession == null) return;

    _currentSession = _currentSession!.copyWith(state: SessionState.paused);
    _sessionController.add(_currentSession);
  }

  /// Send audio data (host only).
  void sendAudio({
    required List<int> audioData,
    required int channelMask,
  }) {
    if (!_isHost) return;
    _audioStreamer.sendAudio(
      audioData: audioData is Uint8List ? audioData : Uint8List.fromList(audioData),
      channelMask: channelMask,
    );
  }

  /// Leave current session.
  Future<void> leaveSession() async {
    await _timeSync.dispose();
    await _audioStreamer.stop();
    await _discoveryService.stop();

    _currentSession = null;
    _isHost = false;

    if (!_sessionController.isClosed) {
      _sessionController.add(null);
    }
  }

  Future<void> dispose() async {
    await leaveSession();

    if (!_sessionController.isClosed) {
      await _sessionController.close();
    }
    if (!_packetController.isClosed) {
      await _packetController.close();
    }
  }
}
