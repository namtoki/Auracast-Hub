import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio/audio.dart';
import '../../core/network/network.dart';
import '../../models/models.dart';

class ClientScreen extends StatefulWidget {
  final DeviceInfo localDevice;
  final DiscoveredHost host;
  final VoidCallback onLeaveSession;

  const ClientScreen({
    super.key,
    required this.localDevice,
    required this.host,
    required this.onLeaveSession,
  });

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  late SyncProtocol _syncProtocol;
  late AudioEngine _audioEngine;
  late AudioBuffer _audioBuffer;
  Session? _session;
  bool _isConnected = false;
  bool _isSynced = false;
  int _syncOffsetUs = 0;
  int _rttUs = 0;
  Timer? _playbackTimer;
  BufferStats? _bufferStats;

  @override
  void initState() {
    super.initState();
    _syncProtocol = SyncProtocol();
    _audioEngine = AudioEngine();
    _audioBuffer = AudioBuffer(targetBufferMs: 100);
    _initializeClient();
  }

  Future<void> _initializeClient() async {
    _syncProtocol.initialize(widget.localDevice);

    // Initialize audio engine
    await _audioEngine.initialize(
      sampleRate: 48000,
      channelCount: 2,
      bufferSizeMs: 100,
    );

    // Join session
    await _syncProtocol.joinSession(widget.host);

    // Listen for session updates
    _syncProtocol.sessionStream.listen((session) {
      if (mounted) {
        setState(() {
          _session = session;
          _isConnected = session != null;
        });
      }
    });

    // Listen for time sync updates
    _syncProtocol.timeSync.onSyncUpdate?.call;
    _startTimeSyncMonitor();

    // Listen for audio packets
    _syncProtocol.packetStream.listen((packet) {
      _audioBuffer.addPacket(packet);
    });

    // Start playback loop
    _startPlaybackLoop();
    await _audioEngine.startPlayback();
  }

  void _startTimeSyncMonitor() {
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _isSynced = _syncProtocol.timeSync.isSynced;
        _syncOffsetUs = _syncProtocol.timeSync.clockOffsetUs;
        _rttUs = _syncProtocol.timeSync.rttUs;
        _bufferStats = _audioBuffer.getStats();
      });
    });
  }

  void _startPlaybackLoop() {
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 10), (_) {
      if (!_isSynced) return;

      final currentTimeUs = _syncProtocol.timeSync.currentTimeSyncedUs;
      final packets = _audioBuffer.getReadyPackets(currentTimeUs);

      for (final packet in packets) {
        // Queue audio for playback
        _audioEngine.queueAudio(
          data: packet.payload,
          playTimeUs: packet.playTimeUs,
          channelMask: packet.channelMask,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final assignment = _session?.getChannelAssignment(widget.localDevice.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Client'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () async {
              await _syncProtocol.leaveSession();
              await _audioEngine.dispose();
              widget.onLeaveSession();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Connection Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isConnected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: _isConnected ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isConnected ? 'Connected' : 'Connecting...',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Host', widget.host.sessionName),
                    _buildInfoRow('Host IP', widget.host.ipAddress),
                    _buildInfoRow(
                        'Session', _session?.id ?? widget.host.sessionId),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Sync Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isSynced
                              ? Icons.sync
                              : Icons.sync_problem,
                          color: _isSynced ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isSynced ? 'Synchronized' : 'Synchronizing...',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      'Clock Offset',
                      '${(_syncOffsetUs / 1000).toStringAsFixed(2)} ms',
                    ),
                    _buildInfoRow(
                      'Round Trip Time',
                      '${(_rttUs / 1000).toStringAsFixed(2)} ms',
                    ),
                    if (_bufferStats != null) ...[
                      const Divider(),
                      _buildInfoRow(
                        'Buffer Fill',
                        '${(_bufferStats!.fillLevel * 100).toStringAsFixed(0)}%',
                      ),
                      _buildInfoRow(
                        'Packets Buffered',
                        '${_bufferStats!.bufferedPackets}',
                      ),
                      if (_bufferStats!.packetsDropped > 0)
                        _buildInfoRow(
                          'Packets Dropped',
                          '${_bufferStats!.packetsDropped}',
                          valueColor: Colors.red,
                        ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Channel Assignment Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Channel Assignment',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: _getChannelColor(assignment?.channel),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).primaryColor,
                            width: 3,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                assignment?.channel.code ?? 'STEREO',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                assignment?.channel.displayName ?? 'Stereo',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (assignment != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.volume_up, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Volume: ${((assignment.volume ?? 1.0) * 100).toInt()}%',
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Playback Status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _session?.state == SessionState.playing
                    ? Colors.green.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _session?.state == SessionState.playing
                        ? Icons.play_circle_filled
                        : Icons.pause_circle_filled,
                    size: 32,
                    color: _session?.state == SessionState.playing
                        ? Colors.green
                        : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _session?.state == SessionState.playing
                        ? 'Playing'
                        : 'Waiting for host...',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Color _getChannelColor(AudioChannel? channel) {
    switch (channel) {
      case AudioChannel.left:
        return Colors.blue[50]!;
      case AudioChannel.right:
        return Colors.red[50]!;
      case AudioChannel.center:
        return Colors.green[50]!;
      default:
        return Colors.grey[100]!;
    }
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _audioEngine.dispose();
    _syncProtocol.dispose();
    super.dispose();
  }
}
