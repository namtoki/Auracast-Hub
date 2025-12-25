import 'dart:async';
import 'dart:typed_data';

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
  late ChannelSplitter _channelSplitter;
  Session? _session;
  bool _isConnected = false;
  bool _isSynced = false;
  int _syncOffsetUs = 0;
  int _rttUs = 0;
  Timer? _playbackTimer;
  BufferStats? _bufferStats;

  // Channel assignment from host
  int _assignedChannelMask = 0x03; // Default to stereo
  int _assignedVolume = 100;
  int _assignedDelayMs = 0;

  @override
  void initState() {
    super.initState();
    _syncProtocol = SyncProtocol();
    _audioEngine = AudioEngine();
    // Increase buffer to 150ms for more stable playback over WiFi
    _audioBuffer = AudioBuffer(targetBufferMs: 150);
    _channelSplitter = ChannelSplitter();
    _initializeClient();
  }

  Future<void> _initializeClient() async {
    _syncProtocol.initialize(widget.localDevice);

    // Initialize audio engine
    await _audioEngine.initialize(
      sampleRate: 48000,
      channelCount: 2,
      bufferSizeMs: 10,
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

    // Listen for channel assignment updates
    _syncProtocol.channelAssignmentStream.listen((assignment) {
      if (mounted) {
        setState(() {
          _assignedChannelMask = assignment.channelMask;
          _assignedVolume = assignment.volume;
          _assignedDelayMs = assignment.delayMs;
        });
        print('[ClientScreen] Channel assignment updated: mask=0x${assignment.channelMask.toRadixString(16)}, volume=${assignment.volume}%, delay=${assignment.delayMs}ms');
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
    int loopCount = 0;
    int totalPacketsPlayed = 0;

    // Run playback loop every 5ms for smoother audio
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 5), (_) {
      if (!_isSynced) return;

      final currentTimeUs = _syncProtocol.timeSync.currentTimeSyncedUs;
      final packets = _audioBuffer.getReadyPackets(currentTimeUs);

      loopCount++;
      if (packets.isNotEmpty) {
        totalPacketsPlayed += packets.length;
        if (totalPacketsPlayed <= 10 || loopCount % 200 == 0) {
          print('[ClientScreen] Playing ${packets.length} packets, total: $totalPacketsPlayed, buffer: ${_audioBuffer.bufferedPackets}, channel: 0x${_assignedChannelMask.toRadixString(16)}');
        }
      }

      for (final packet in packets) {
        // Extract assigned channel from stereo audio
        final audioData = _extractAssignedChannel(packet.payload);

        // Queue audio for playback
        _audioEngine.queueAudio(
          data: audioData,
          playTimeUs: packet.playTimeUs,
          channelMask: _assignedChannelMask,
        );
      }
    });
  }

  /// Extract assigned channel from stereo audio data.
  /// Returns stereo data with only the assigned channel.
  Uint8List _extractAssignedChannel(Uint8List stereoData) {
    // 0x01 = Left only, 0x02 = Right only, 0x03 = Stereo
    if (_assignedChannelMask == 0x03) {
      // Stereo - return as-is
      return stereoData;
    }

    // For L or R only, extract the channel and duplicate to both speakers
    final channelIndex = (_assignedChannelMask == 0x01) ? 0 : 1;
    final monoData = _channelSplitter.extractChannel(stereoData, channelIndex);

    // Convert mono to stereo (duplicate the channel)
    return _monoToStereo(monoData);
  }

  /// Convert mono audio to stereo by duplicating the channel.
  Uint8List _monoToStereo(Uint8List monoData) {
    final stereoData = Uint8List(monoData.length * 2);
    const bytesPerSample = 2; // 16-bit

    for (var i = 0; i < monoData.length; i += bytesPerSample) {
      // Copy sample to left channel
      stereoData[i * 2] = monoData[i];
      stereoData[i * 2 + 1] = monoData[i + 1];
      // Copy same sample to right channel
      stereoData[i * 2 + 2] = monoData[i];
      stereoData[i * 2 + 3] = monoData[i + 1];
    }

    return stereoData;
  }

  /// Get the display name for the assigned channel.
  String get _assignedChannelName {
    switch (_assignedChannelMask) {
      case 0x01:
        return 'Left';
      case 0x02:
        return 'Right';
      case 0x03:
        return 'Stereo';
      case 0x04:
        return 'Center';
      default:
        return 'Unknown';
    }
  }

  String get _assignedChannelCode {
    switch (_assignedChannelMask) {
      case 0x01:
        return 'L';
      case 0x02:
        return 'R';
      case 0x03:
        return 'STEREO';
      case 0x04:
        return 'C';
      default:
        return '?';
    }
  }

  @override
  Widget build(BuildContext context) {
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
                          color: _getChannelColorFromMask(_assignedChannelMask),
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
                                _assignedChannelCode,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _assignedChannelName,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.volume_up, size: 20),
                        const SizedBox(width: 8),
                        Text('Volume: $_assignedVolume%'),
                        if (_assignedDelayMs != 0) ...[
                          const SizedBox(width: 16),
                          const Icon(Icons.timer, size: 20),
                          const SizedBox(width: 8),
                          Text('Delay: ${_assignedDelayMs}ms'),
                        ],
                      ],
                    ),
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

  Color _getChannelColorFromMask(int channelMask) {
    switch (channelMask) {
      case 0x01: // Left
        return Colors.blue[100]!;
      case 0x02: // Right
        return Colors.red[100]!;
      case 0x04: // Center
        return Colors.green[100]!;
      case 0x03: // Stereo
        return Colors.purple[100]!;
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
