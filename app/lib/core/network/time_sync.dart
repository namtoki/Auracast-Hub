import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// NTP-style time synchronization between host and clients.
/// Achieves sub-millisecond sync accuracy using round-trip time measurement.
class TimeSync {
  static const int _syncPort = 5353;
  static const int _syncIntervalMs = 1000;
  static const int _maxSamples = 10;

  RawDatagramSocket? _socket;
  Timer? _syncTimer;
  final List<TimeSyncSample> _samples = [];

  int _clockOffsetUs = 0; // Offset from host clock in microseconds
  int _rttUs = 0; // Round-trip time in microseconds
  bool _isSynced = false;

  final void Function(int offsetUs, int rttUs)? onSyncUpdate;

  TimeSync({this.onSyncUpdate});

  /// Current clock offset from host in microseconds.
  int get clockOffsetUs => _clockOffsetUs;

  /// Current round-trip time in microseconds.
  int get rttUs => _rttUs;

  /// Whether time sync is established.
  bool get isSynced => _isSynced;

  /// Get current synchronized time in microseconds (host time).
  int get currentTimeSyncedUs =>
      DateTime.now().microsecondsSinceEpoch + _clockOffsetUs;

  /// Start time sync as host.
  Future<void> startAsHost() async {
    await _stop();
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _syncPort);
    _socket!.listen(_handleHostReceive);
    _isSynced = true;
    _clockOffsetUs = 0;
  }

  /// Start time sync as client.
  Future<void> startAsClient(String hostAddress) async {
    await _stop();
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _socket!.listen((event) => _handleClientReceive(event, hostAddress));

    // Start periodic sync
    _syncTimer = Timer.periodic(
      const Duration(milliseconds: _syncIntervalMs),
      (_) => _sendSyncRequest(hostAddress),
    );

    // Send initial sync request
    _sendSyncRequest(hostAddress);
  }

  void _handleHostReceive(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;

    final datagram = _socket!.receive();
    if (datagram == null) return;

    final data = datagram.data;
    if (data.length < 16) return;

    // Parse client request
    final buffer = ByteData.sublistView(data);
    final magic = buffer.getUint32(0); // "SYNC"
    if (magic != 0x53594E43) return;

    final clientT1 = buffer.getInt64(8);
    final t2 = DateTime.now().microsecondsSinceEpoch;

    // Build response
    final response = Uint8List(32);
    final respBuffer = ByteData.sublistView(response);
    respBuffer.setUint32(0, 0x53594E43); // "SYNC"
    respBuffer.setUint32(4, 0x01); // Response type
    respBuffer.setInt64(8, clientT1); // Echo client T1
    respBuffer.setInt64(16, t2); // Server T2
    respBuffer.setInt64(24, DateTime.now().microsecondsSinceEpoch); // Server T3

    _socket!.send(response, datagram.address, datagram.port);
  }

  void _handleClientReceive(RawSocketEvent event, String hostAddress) {
    if (event != RawSocketEvent.read) return;

    final datagram = _socket!.receive();
    if (datagram == null) return;

    final t4 = DateTime.now().microsecondsSinceEpoch;
    final data = datagram.data;
    if (data.length < 32) return;

    final buffer = ByteData.sublistView(data);
    final magic = buffer.getUint32(0);
    if (magic != 0x53594E43) return;

    final type = buffer.getUint32(4);
    if (type != 0x01) return;

    final t1 = buffer.getInt64(8);
    final t2 = buffer.getInt64(16);
    final t3 = buffer.getInt64(24);

    // Calculate offset and RTT using NTP algorithm
    // RTT = (T4 - T1) - (T3 - T2)
    // Offset = ((T2 - T1) + (T3 - T4)) / 2
    final rtt = (t4 - t1) - (t3 - t2);
    final offset = ((t2 - t1) + (t3 - t4)) ~/ 2;

    _samples.add(TimeSyncSample(
      t1: t1,
      t2: t2,
      t3: t3,
      t4: t4,
      rttUs: rtt,
      offsetUs: offset,
    ));

    if (_samples.length > _maxSamples) {
      _samples.removeAt(0);
    }

    _updateSync();
  }

  void _sendSyncRequest(String hostAddress) {
    if (_socket == null) return;

    final t1 = DateTime.now().microsecondsSinceEpoch;
    final request = Uint8List(16);
    final buffer = ByteData.sublistView(request);
    buffer.setUint32(0, 0x53594E43); // "SYNC"
    buffer.setUint32(4, 0x00); // Request type
    buffer.setInt64(8, t1);

    try {
      _socket!.send(request, InternetAddress(hostAddress), _syncPort);
    } catch (_) {}
  }

  void _updateSync() {
    if (_samples.isEmpty) return;

    // Use median filtering to remove outliers
    final sortedByRtt = List<TimeSyncSample>.from(_samples)
      ..sort((a, b) => a.rttUs.compareTo(b.rttUs));

    // Take samples with lowest RTT (most reliable)
    final bestSamples = sortedByRtt.take(5).toList();
    if (bestSamples.isEmpty) return;

    // Average the offsets from best samples
    final avgOffset =
        bestSamples.map((s) => s.offsetUs).reduce((a, b) => a + b) ~/
            bestSamples.length;
    final minRtt = bestSamples.first.rttUs;

    _clockOffsetUs = avgOffset;
    _rttUs = minRtt;
    _isSynced = true;

    onSyncUpdate?.call(_clockOffsetUs, _rttUs);
  }

  Future<void> _stop() async {
    _syncTimer?.cancel();
    _syncTimer = null;
    _socket?.close();
    _socket = null;
    _samples.clear();
    _isSynced = false;
  }

  Future<void> dispose() async {
    await _stop();
  }
}

class TimeSyncSample {
  final int t1; // Client send time
  final int t2; // Server receive time
  final int t3; // Server send time
  final int t4; // Client receive time
  final int rttUs;
  final int offsetUs;

  const TimeSyncSample({
    required this.t1,
    required this.t2,
    required this.t3,
    required this.t4,
    required this.rttUs,
    required this.offsetUs,
  });
}
