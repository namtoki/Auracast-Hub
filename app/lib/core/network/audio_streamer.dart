import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'audio_packet.dart';
import 'time_sync.dart';

/// Streams audio packets from host to clients via UDP.
class AudioStreamer {
  static const int audioPort = 5355;
  static const int defaultBufferMs = 100;

  RawDatagramSocket? _socket;
  final Set<InternetAddress> _clients = {};
  int _sequenceNumber = 0;
  final TimeSync _timeSync;
  int _bufferMs;

  AudioStreamer({
    required TimeSync timeSync,
    int bufferMs = defaultBufferMs,
  })  : _timeSync = timeSync,
        _bufferMs = bufferMs;

  /// Buffer size in milliseconds.
  int get bufferMs => _bufferMs;
  set bufferMs(int value) => _bufferMs = value;

  /// Start streaming as host.
  Future<void> startHost() async {
    await stop();
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, audioPort);
    _socket!.listen(_handleHostReceive);
  }

  /// Start receiving as client.
  Future<void> startClient(
    String hostAddress,
    void Function(AudioPacket packet) onPacketReceived,
  ) async {
    await stop();
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

    // Register with host
    _sendClientRegistration(hostAddress);

    _socket!.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = _socket!.receive();
      if (datagram == null) return;

      final packet = AudioPacket.fromBytes(datagram.data);
      if (packet != null) {
        onPacketReceived(packet);
      }
    });
  }

  void _handleHostReceive(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;

    final datagram = _socket!.receive();
    if (datagram == null) return;

    // Check for client registration
    if (datagram.data.length >= 4) {
      final view = ByteData.sublistView(datagram.data);
      if (view.getUint32(0) == 0x52454749) {
        // "REGI"
        _clients.add(datagram.address);
      }
    }
  }

  void _sendClientRegistration(String hostAddress) {
    if (_socket == null) return;

    final data = Uint8List(4);
    ByteData.sublistView(data).setUint32(0, 0x52454749); // "REGI"

    try {
      _socket!.send(data, InternetAddress(hostAddress), audioPort);
    } catch (_) {}
  }

  /// Send audio data to all clients.
  void sendAudio({
    required Uint8List audioData,
    required int channelMask,
  }) {
    if (_socket == null) return;

    // Calculate play time: current time + buffer delay
    final playTimeUs =
        _timeSync.currentTimeSyncedUs + (_bufferMs * 1000);

    final packet = AudioPacket(
      sequenceNumber: _sequenceNumber++,
      playTimeUs: playTimeUs,
      channelMask: channelMask,
      payload: audioData,
    );

    final bytes = packet.toBytes();

    for (final client in _clients) {
      try {
        _socket!.send(bytes, client, audioPort);
      } catch (_) {}
    }
  }

  /// Remove a client from the stream.
  void removeClient(String address) {
    _clients.removeWhere((c) => c.address == address);
  }

  /// Stop streaming.
  Future<void> stop() async {
    _socket?.close();
    _socket = null;
    _clients.clear();
    _sequenceNumber = 0;
  }

  void dispose() {
    stop();
  }
}
