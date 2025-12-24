import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';

import '../../core/network/network.dart';
import '../../models/models.dart';
import '../client/client_screen.dart';
import '../host/host_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const HomeScreen({
    super.key,
    required this.onLogout,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DeviceInfo? _localDevice;
  final DiscoveryService _discoveryService = DiscoveryService();
  List<DiscoveredHost> _discoveredHosts = [];
  bool _isSearching = false;
  StreamSubscription? _discoverySubscription;

  @override
  void initState() {
    super.initState();
    _initializeDevice();
  }

  Future<void> _initializeDevice() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    String deviceId;
    String deviceName;
    String model;
    String platform;
    String osVersion;

    if (Platform.isIOS) {
      final iosInfo = await deviceInfoPlugin.iosInfo;
      deviceId = iosInfo.identifierForVendor ?? 'unknown';
      deviceName = iosInfo.name;
      model = iosInfo.model;
      platform = 'ios';
      osVersion = iosInfo.systemVersion;
    } else if (Platform.isAndroid) {
      final androidInfo = await deviceInfoPlugin.androidInfo;
      deviceId = androidInfo.id;
      deviceName = androidInfo.model;
      model = androidInfo.model;
      platform = 'android';
      osVersion = androidInfo.version.release;
    } else {
      deviceId = 'unknown';
      deviceName = 'Unknown Device';
      model = 'Unknown';
      platform = 'unknown';
      osVersion = 'unknown';
    }

    setState(() {
      _localDevice = DeviceInfo(
        id: deviceId,
        name: deviceName,
        model: model,
        platform: platform,
        osVersion: osVersion,
      );
    });
  }

  Future<void> _startSearching() async {
    setState(() {
      _isSearching = true;
      _discoveredHosts = [];
    });

    await _discoveryService.startDiscovery();

    _discoverySubscription = _discoveryService.hostsStream.listen((hosts) {
      if (mounted) {
        setState(() {
          _discoveredHosts = hosts;
        });
      }
    });
  }

  void _stopSearching() {
    _discoverySubscription?.cancel();
    _discoveryService.stop();
    setState(() {
      _isSearching = false;
    });
  }

  void _startAsHost() {
    if (_localDevice == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HostScreen(
          localDevice: _localDevice!,
          onLeaveSession: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _joinSession(DiscoveredHost host) {
    if (_localDevice == null) return;

    _stopSearching();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClientScreen(
          localDevice: _localDevice!,
          host: host,
          onLeaveSession: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SpatialSync'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Open settings
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: _localDevice == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Device Info Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Platform.isIOS
                                    ? Icons.phone_iphone
                                    : Icons.phone_android,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _localDevice!.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    Text(
                                      '${_localDevice!.model} - ${_localDevice!.platform.toUpperCase()} ${_localDevice!.osVersion}',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Role Selection
                  Text(
                    'Start a Session',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),

                  // Host Button
                  _RoleCard(
                    icon: Icons.broadcast_on_personal,
                    title: 'Host',
                    description:
                        'Stream audio to other devices.\nSelect music and control playback.',
                    color: Colors.blue,
                    onTap: _startAsHost,
                  ),

                  const SizedBox(height: 12),

                  // Client Button
                  _RoleCard(
                    icon: Icons.speaker_group,
                    title: 'Client',
                    description:
                        'Receive audio from a host.\nBecome a speaker in the system.',
                    color: Colors.green,
                    onTap: () {
                      if (_isSearching) {
                        _stopSearching();
                      } else {
                        _startSearching();
                      }
                    },
                    trailing: _isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                  ),

                  // Discovered Hosts
                  if (_isSearching || _discoveredHosts.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Available Sessions',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (_isSearching)
                          TextButton(
                            onPressed: _stopSearching,
                            child: const Text('Stop'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_discoveredHosts.isEmpty && _isSearching)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              'Searching for hosts...',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    else
                      ...(_discoveredHosts.map(
                        (host) => Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(host.sessionName[0].toUpperCase()),
                            ),
                            title: Text(host.sessionName),
                            subtitle: Text(
                              '${host.hostDevice.name} @ ${host.ipAddress}',
                            ),
                            trailing: FilledButton(
                              onPressed: () => _joinSession(host),
                              child: const Text('Join'),
                            ),
                          ),
                        ),
                      )),
                  ],

                  const SizedBox(height: 32),

                  // Info Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Text(
                              'How it works',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '1. One device hosts the session and plays music\n'
                          '2. Other devices join as clients\n'
                          '3. Assign L/R channels to each client\n'
                          '4. All devices play in perfect sync',
                          style: TextStyle(
                            color: Colors.blue[900],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _discoverySubscription?.cancel();
    _discoveryService.dispose();
    super.dispose();
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;
  final Widget? trailing;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              trailing ?? Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
