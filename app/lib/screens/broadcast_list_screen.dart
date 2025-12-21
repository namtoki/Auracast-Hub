import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/auracast_service.dart';

class BroadcastListScreen extends StatefulWidget {
  final VoidCallback? onLogout;

  const BroadcastListScreen({super.key, this.onLogout});

  @override
  State<BroadcastListScreen> createState() => _BroadcastListScreenState();
}

class _BroadcastListScreenState extends State<BroadcastListScreen> {
  final AuracastService _auracastService = AuracastService();
  final Map<String, DiscoveredBroadcast> _broadcasts = {};
  StreamSubscription<DiscoveredBroadcast>? _scanSubscription;

  bool _isScanning = false;
  bool _isSupported = false;
  bool _isBluetoothEnabled = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkSupport();
  }

  @override
  void dispose() {
    _stopScan();
    super.dispose();
  }

  Future<void> _checkSupport() async {
    final isSupported = await _auracastService.isLeAudioSupported();
    final isBluetoothEnabled = await _auracastService.isBluetoothEnabled();

    setState(() {
      _isSupported = isSupported;
      _isBluetoothEnabled = isBluetoothEnabled;
    });
  }

  Future<bool> _requestPermissions() async {
    final bluetoothScan = await Permission.bluetoothScan.request();
    final bluetoothConnect = await Permission.bluetoothConnect.request();

    if (bluetoothScan.isDenied || bluetoothConnect.isDenied) {
      setState(() {
        _errorMessage = 'Bluetooth permissions are required to scan for broadcasts';
      });
      return false;
    }

    return true;
  }

  Future<void> _startScan() async {
    if (!await _requestPermissions()) {
      return;
    }

    setState(() {
      _isScanning = true;
      _errorMessage = null;
      _broadcasts.clear();
    });

    _scanSubscription = _auracastService.scanStream.listen(
      (broadcast) {
        setState(() {
          _broadcasts[broadcast.address] = broadcast;
        });
      },
      onError: (error) {
        setState(() {
          _isScanning = false;
          _errorMessage = error.toString();
        });
      },
      onDone: () {
        setState(() {
          _isScanning = false;
        });
      },
    );
  }

  Future<void> _stopScan() async {
    await _scanSubscription?.cancel();
    await _auracastService.stopScan();
    setState(() {
      _isScanning = false;
    });
  }

  List<DiscoveredBroadcast> get _sortedBroadcasts {
    final list = _broadcasts.values.toList();
    list.sort((a, b) => b.rssi.compareTo(a.rssi)); // Sort by RSSI (strongest first)
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auracast Broadcasts'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkSupport,
            tooltip: 'Refresh status',
          ),
        ],
      ),
      drawer: widget.onLogout != null ? _buildDrawer(context) : null,
      body: Column(
        children: [
          _buildStatusCard(),
          if (_errorMessage != null) _buildErrorCard(),
          Expanded(
            child: _buildBroadcastList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isScanning ? _stopScan : _startScan,
        icon: Icon(_isScanning ? Icons.stop : Icons.bluetooth_searching),
        label: Text(_isScanning ? 'Stop Scan' : 'Start Scan'),
        backgroundColor: _isScanning ? Colors.red : null,
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const CircleAvatar(
                  radius: 30,
                  child: Icon(Icons.person, size: 30),
                ),
                const SizedBox(height: 12),
                Text(
                  'Auracast Hub',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.broadcast_on_personal),
            title: const Text('Broadcasts'),
            selected: true,
            onTap: () {
              Navigator.pop(context);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            onTap: () {
              Navigator.pop(context);
              _showLogoutConfirmation(context);
            },
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onLogout?.call();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Device Status',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _isBluetoothEnabled ? Icons.bluetooth : Icons.bluetooth_disabled,
                  color: _isBluetoothEnabled ? Colors.blue : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(_isBluetoothEnabled ? 'Bluetooth Enabled' : 'Bluetooth Disabled'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  _isSupported ? Icons.check_circle : Icons.error,
                  color: _isSupported ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(_isSupported
                    ? 'LE Audio Supported'
                    : 'LE Audio Support Unknown'),
              ],
            ),
            if (_isScanning) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Scanning for broadcasts...'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.red.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(_errorMessage!)),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBroadcastList() {
    final broadcasts = _sortedBroadcasts;

    if (broadcasts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broadcast_on_personal,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _isScanning
                  ? 'Searching for Auracast broadcasts...'
                  : 'No broadcasts found\nTap "Start Scan" to begin',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: broadcasts.length,
      itemBuilder: (context, index) {
        final broadcast = broadcasts[index];
        return _buildBroadcastCard(broadcast);
      },
    );
  }

  Widget _buildBroadcastCard(DiscoveredBroadcast broadcast) {
    final rssiColor = _getRssiColor(broadcast.rssi);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: broadcast.isEncrypted ? Colors.amber.shade100 : Colors.green.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            broadcast.isEncrypted ? Icons.lock : Icons.radio,
            color: broadcast.isEncrypted ? Colors.amber.shade800 : Colors.green.shade800,
          ),
        ),
        title: Text(
          broadcast.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${broadcast.broadcastIdHex}'),
            Row(
              children: [
                Icon(Icons.signal_cellular_alt, size: 14, color: rssiColor),
                const SizedBox(width: 4),
                Text('${broadcast.rssi} dBm'),
                const SizedBox(width: 12),
                Text('SID: ${broadcast.advertisingSid}'),
              ],
            ),
          ],
        ),
        trailing: broadcast.isEncrypted
            ? const Chip(
                label: Text('Encrypted'),
                backgroundColor: Colors.amber,
                labelStyle: TextStyle(fontSize: 10),
                padding: EdgeInsets.zero,
              )
            : const Chip(
                label: Text('Open'),
                backgroundColor: Colors.green,
                labelStyle: TextStyle(fontSize: 10, color: Colors.white),
                padding: EdgeInsets.zero,
              ),
        onTap: () {
          _showBroadcastDetails(broadcast);
        },
      ),
    );
  }

  Color _getRssiColor(int rssi) {
    if (rssi >= -50) return Colors.green;
    if (rssi >= -70) return Colors.orange;
    return Colors.red;
  }

  void _showBroadcastDetails(DiscoveredBroadcast broadcast) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                broadcast.displayName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Divider(),
              _buildDetailRow('Address', broadcast.address),
              _buildDetailRow('Address Type', broadcast.addressType.toString()),
              _buildDetailRow('Broadcast ID', broadcast.broadcastIdHex),
              _buildDetailRow('Advertising SID', broadcast.advertisingSid.toString()),
              _buildDetailRow('RSSI', '${broadcast.rssi} dBm'),
              _buildDetailRow('Encrypted', broadcast.isEncrypted ? 'Yes' : 'No'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // TODO: Implement connection to broadcast
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Connection feature coming soon!'),
                      ),
                    );
                  },
                  child: const Text('Connect'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
