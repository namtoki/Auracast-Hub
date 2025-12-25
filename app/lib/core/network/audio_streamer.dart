import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'audio_packet.dart';
import 'time_sync.dart';

/// Client endpoint information (IP + port)
class _ClientEndpoint {
  final InternetAddress address;
  final int port;

  _ClientEndpoint(this.address, this.port);

  @override
  String toString() => '${address.address}:$port';
}

/// Streams audio packets from host to clients via UDP.
class AudioStreamer {
  static const int audioPort = 5355;
  static const int defaultBufferMs = 150; // Match client buffer for stable playback

  RawDatagramSocket? _socket;
  final Map<String, _ClientEndpoint> _clients = {};
  int _sequenceNumber = 0;
  final TimeSync _timeSync;
  int _bufferMs;
  void Function(String clientAddress)? onClientRegistered;

  AudioStreamer({
    required TimeSync timeSync,
    int bufferMs = defaultBufferMs,
    this.onClientRegistered,
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

  Timer? _registrationTimer;

  void Function(ChannelAssignmentPacket assignment)? onChannelAssignment;

  /// Start receiving as client.
  Future<void> startClient(
    String hostAddress,
    void Function(AudioPacket packet) onPacketReceived, {
    void Function(ChannelAssignmentPacket assignment)? onChannelAssignment,
  }) async {
    await stop();
    this.onChannelAssignment = onChannelAssignment;

    // Bind to the same audio port to receive from host
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, audioPort);
      print('[AudioStreamer Client] Successfully bound to port $audioPort');
      print('[AudioStreamer Client] Local address: ${_socket!.address.address}:${_socket!.port}');
    } catch (e) {
      print('[AudioStreamer Client] ERROR: Failed to bind to port $audioPort: $e');
      // Try binding to any available port as fallback
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      print('[AudioStreamer Client] Fallback: bound to port ${_socket!.port}');
    }

    print('[AudioStreamer Client] Waiting for packets from host: $hostAddress');

    // Register with host immediately
    _sendClientRegistration(hostAddress);

    // Keep re-registering periodically in case packets are lost
    _registrationTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _sendClientRegistration(hostAddress);
      print('[AudioStreamer Client] Re-sent registration to $hostAddress:$audioPort');
    });

    int packetCount = 0;
    int totalEvents = 0;
    _socket!.listen((event) {
      totalEvents++;
      if (totalEvents % 100 == 1) {
        print('[AudioStreamer Client] Socket event: $event (total events: $totalEvents, packets: $packetCount)');
      }

      if (event != RawSocketEvent.read) return;
      final datagram = _socket!.receive();
      if (datagram == null) {
        print('[AudioStreamer Client] Received null datagram');
        return;
      }

      // Check for channel assignment packet first
      final channelPacket = ChannelAssignmentPacket.fromBytes(datagram.data);
      if (channelPacket != null) {
        print('[AudioStreamer Client] Received channel assignment: $channelPacket');
        this.onChannelAssignment?.call(channelPacket);
        return;
      }

      packetCount++;
      if (packetCount <= 5 || packetCount % 50 == 0) {
        print('[AudioStreamer Client] Received datagram #$packetCount from ${datagram.address.address}:${datagram.port}, size: ${datagram.data.length}');
      }

      final packet = AudioPacket.fromBytes(datagram.data);
      if (packet != null) {
        if (packetCount <= 5) {
          print('[AudioStreamer Client] Parsed packet seq=${packet.sequenceNumber}, playTime=${packet.playTimeUs}');
        }
        onPacketReceived(packet);
      } else {
        print('[AudioStreamer Client] Failed to parse packet, size: ${datagram.data.length}, first bytes: ${datagram.data.take(20).toList()}');
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
        final clientKey = '${datagram.address.address}:${datagram.port}';
        final isNew = !_clients.containsKey(clientKey);
        _clients[clientKey] = _ClientEndpoint(datagram.address, datagram.port);
        print('[AudioStreamer Host] Client registered: $clientKey, total clients: ${_clients.length}, isNew: $isNew');
        if (isNew) {
          onClientRegistered?.call(datagram.address.address);
        }
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

  /// Maximum payload size for UDP (MTU safe)
  static const int _maxPayloadSize = 1400;

  /// Send audio data to all clients.
  void sendAudio({
    required Uint8List audioData,
    required int channelMask,
  }) {
    if (_socket == null) return;

    if (_clients.isEmpty) {
      if (_sequenceNumber % 100 == 0) {
        print('[AudioStreamer] No clients connected, skipping send (seq: $_sequenceNumber)');
      }
      _sequenceNumber++;
      return;
    }

    // Split large audio data into smaller chunks
    int offset = 0;
    while (offset < audioData.length) {
      final chunkSize = (audioData.length - offset).clamp(0, _maxPayloadSize);
      final chunk = audioData.sublist(offset, offset + chunkSize);

      // Calculate play time based on offset in samples
      // Each sample is 4 bytes (2 channels * 2 bytes per sample)
      final sampleOffset = offset ~/ 4;
      final timeOffsetUs = (sampleOffset * 1000000) ~/ 48000;
      final playTimeUs = _timeSync.currentTimeSyncedUs + (_bufferMs * 1000) + timeOffsetUs;

      final packet = AudioPacket(
        sequenceNumber: _sequenceNumber++,
        playTimeUs: playTimeUs,
        channelMask: channelMask,
        payload: Uint8List.fromList(chunk),
      );

      final bytes = packet.toBytes();

      for (final client in _clients.values) {
        try {
          final sent = _socket!.send(bytes, client.address, client.port);
          if (_sequenceNumber <= 5 || _sequenceNumber % 100 == 0) {
            print('[AudioStreamer Host] Sent $sent bytes to ${client.address.address}:${client.port}, seq: ${_sequenceNumber - 1}, packetSize: ${bytes.length}');
          }
        } catch (e) {
          print('[AudioStreamer Host] Send error to $client: $e');
        }
      }

      offset += chunkSize;
    }
  }

  /// Remove a client from the stream.
  void removeClient(String address) {
    _clients.removeWhere((key, client) => client.address.address == address);
  }

  /// Send channel assignment to a specific client.
  void sendChannelAssignment({
    required String clientAddress,
    required int channelMask,
    int volume = 100,
    int delayMs = 0,
  }) {
    if (_socket == null) return;

    // Find the client endpoint
    final client = _clients.values.where(
      (c) => c.address.address == clientAddress,
    ).firstOrNull;

    if (client == null) {
      print('[AudioStreamer] Client not found for channel assignment: $clientAddress');
      return;
    }

    final packet = ChannelAssignmentPacket(
      channelMask: channelMask,
      volume: volume,
      delayMs: delayMs,
    );

    final bytes = packet.toBytes();

    try {
      _socket!.send(bytes, client.address, client.port);
      print('[AudioStreamer] Sent channel assignment to $clientAddress: channel=0x${channelMask.toRadixString(16)}, volume=$volume%, delay=${delayMs}ms');
    } catch (e) {
      print('[AudioStreamer] Failed to send channel assignment: $e');
    }
  }

  /// Get list of connected client addresses.
  List<String> get connectedClientAddresses {
    return _clients.values.map((c) => c.address.address).toList();
  }

  /// Stop streaming.
  Future<void> stop() async {
    _registrationTimer?.cancel();
    _registrationTimer = null;
    _socket?.close();
    _socket = null;
    _clients.clear();
    _sequenceNumber = 0;
  }

  void dispose() {
    stop();
  }
}
