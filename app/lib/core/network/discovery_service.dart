import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../models/device_info.dart';

/// Service for discovering SpatialSync hosts on the local network.
/// Uses UDP multicast for host advertisement and discovery.
class DiscoveryService {
  static const String multicastAddress = '239.255.255.250';
  static const int discoveryPort = 5354;
  static const int broadcastIntervalMs = 1000;

  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  final Map<String, DiscoveredHost> _discoveredHosts = {};
  final _hostsController = StreamController<List<DiscoveredHost>>.broadcast();

  /// Stream of discovered hosts.
  Stream<List<DiscoveredHost>> get hostsStream => _hostsController.stream;

  /// Current list of discovered hosts.
  List<DiscoveredHost> get hosts => _discoveredHosts.values.toList();

  /// Start advertising as host.
  Future<void> startAdvertising({
    required String sessionId,
    required String sessionName,
    required DeviceInfo hostDevice,
  }) async {
    await stop();

    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

    _broadcastTimer = Timer.periodic(
      const Duration(milliseconds: broadcastIntervalMs),
      (_) => _sendAdvertisement(sessionId, sessionName, hostDevice),
    );

    // Send initial advertisement
    _sendAdvertisement(sessionId, sessionName, hostDevice);
  }

  void _sendAdvertisement(
    String sessionId,
    String sessionName,
    DeviceInfo hostDevice,
  ) {
    if (_socket == null) return;

    final message = {
      'type': 'host_advertisement',
      'sessionId': sessionId,
      'sessionName': sessionName,
      'host': hostDevice.toJson(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    final data = utf8.encode(jsonEncode(message));

    try {
      _socket!.send(
        data,
        InternetAddress(multicastAddress),
        discoveryPort,
      );
    } catch (_) {}
  }

  /// Start discovering hosts.
  Future<void> startDiscovery() async {
    await stop();

    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
    );

    // Join multicast group
    final multicast = InternetAddress(multicastAddress);
    try {
      _socket!.joinMulticast(multicast);
    } catch (_) {}

    _socket!.listen(_handleDiscoveryReceive);

    // Start cleanup timer for stale hosts
    _broadcastTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _cleanupStaleHosts(),
    );
  }

  void _handleDiscoveryReceive(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;

    final datagram = _socket!.receive();
    if (datagram == null) return;

    try {
      final message = jsonDecode(utf8.decode(datagram.data));
      if (message['type'] != 'host_advertisement') return;

      final host = DiscoveredHost(
        sessionId: message['sessionId'] as String,
        sessionName: message['sessionName'] as String,
        hostDevice: DeviceInfo.fromJson(message['host']),
        ipAddress: datagram.address.address,
        lastSeen: DateTime.now(),
      );

      _discoveredHosts[host.sessionId] = host;
      _notifyHosts();
    } catch (_) {}
  }

  void _cleanupStaleHosts() {
    final now = DateTime.now();
    final staleThreshold = const Duration(seconds: 10);

    _discoveredHosts.removeWhere(
      (_, host) => now.difference(host.lastSeen) > staleThreshold,
    );

    _notifyHosts();
  }

  void _notifyHosts() {
    _hostsController.add(_discoveredHosts.values.toList());
  }

  /// Stop discovery/advertising.
  Future<void> stop() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _socket?.close();
    _socket = null;
    _discoveredHosts.clear();
  }

  void dispose() {
    stop();
    _hostsController.close();
  }
}

/// Represents a discovered host on the network.
class DiscoveredHost {
  final String sessionId;
  final String sessionName;
  final DeviceInfo hostDevice;
  final String ipAddress;
  final DateTime lastSeen;

  const DiscoveredHost({
    required this.sessionId,
    required this.sessionName,
    required this.hostDevice,
    required this.ipAddress,
    required this.lastSeen,
  });

  @override
  String toString() =>
      'DiscoveredHost($sessionName @ $ipAddress, host: ${hostDevice.name})';
}
