import 'package:flutter/material.dart';

import '../../core/audio/audio.dart';
import '../../core/network/network.dart';
import '../../models/models.dart';
import '../setup/manual_assign_screen.dart';

class HostScreen extends StatefulWidget {
  final DeviceInfo localDevice;
  final VoidCallback onLeaveSession;

  const HostScreen({
    super.key,
    required this.localDevice,
    required this.onLeaveSession,
  });

  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  late SyncProtocol _syncProtocol;
  late AudioEngine _audioEngine;
  Session? _session;
  bool _isPlaying = false;
  String? _selectedFilePath;
  String? _selectedFileName;

  @override
  void initState() {
    super.initState();
    _syncProtocol = SyncProtocol();
    _audioEngine = AudioEngine();
    _initializeHost();
  }

  Future<void> _initializeHost() async {
    _syncProtocol.initialize(widget.localDevice);

    // Create session
    final session = await _syncProtocol.createSession();
    setState(() {
      _session = session;
    });

    // Initialize audio engine
    await _audioEngine.initialize(
      sampleRate: 48000,
      channelCount: 2,
      bufferSizeMs: 100,
    );

    // Listen for session updates
    _syncProtocol.sessionStream.listen((session) {
      if (mounted) {
        setState(() {
          _session = session;
        });
      }
    });

    // Listen for audio frames and stream to clients
    _audioEngine.audioFrameStream.listen((frame) {
      _syncProtocol.sendAudio(
        audioData: frame.data.toList(),
        channelMask: 0x03, // Stereo
      );
    });
  }

  Future<void> _selectAudioFile() async {
    // In a real app, use file_picker package
    // For now, show a placeholder dialog
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Audio File'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.music_note),
              title: const Text('Sample Track 1'),
              onTap: () => Navigator.pop(context, '/sample/track1.m4a'),
            ),
            ListTile(
              leading: const Icon(Icons.music_note),
              title: const Text('Sample Track 2'),
              onTap: () => Navigator.pop(context, '/sample/track2.m4a'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _selectedFilePath = result;
        _selectedFileName = result.split('/').last;
      });
    }
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _audioEngine.stopPlayback();
      await _audioEngine.stopCapture();
      _syncProtocol.pausePlayback();
    } else {
      if (_selectedFilePath != null) {
        await _audioEngine.startCapture(
          source: AudioSource.file(_selectedFilePath!),
        );
        await _audioEngine.startPlayback();
        _syncProtocol.startPlayback();
      }
    }

    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  void _openChannelAssignment() {
    if (_session == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManualAssignScreen(
          session: _session!,
          onAssignmentChanged: (assignments) {
            for (final assignment in assignments) {
              _syncProtocol.updateChannelAssignment(assignment);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connectedDevices = _session?.clientDevices ?? [];
    final localIp = _getLocalIp();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Host Session'),
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
      body: Column(
        children: [
          // Session Info Card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _session?.name ?? 'Creating session...',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Session ID: ${_session?.id ?? '-'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'IP Address: $localIp',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        _session?.state == SessionState.playing
                            ? Icons.play_circle
                            : Icons.pause_circle,
                        color: _session?.state == SessionState.playing
                            ? Colors.green
                            : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _session?.state.name.toUpperCase() ?? 'IDLE',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Audio Source Section
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Audio Source',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _selectAudioFile,
                          icon: const Icon(Icons.folder_open),
                          label: Text(
                            _selectedFileName ?? 'Select File',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed:
                            _selectedFilePath != null ? _togglePlayback : null,
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                        label: Text(_isPlaying ? 'Pause' : 'Play'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Connected Devices Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Connected Devices (${connectedDevices.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton.icon(
                  onPressed:
                      connectedDevices.isNotEmpty ? _openChannelAssignment : null,
                  icon: const Icon(Icons.tune),
                  label: const Text('Assign Channels'),
                ),
              ],
            ),
          ),

          Expanded(
            child: connectedDevices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.devices,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Waiting for devices to connect...',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Share session ID: ${_session?.id ?? '-'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: connectedDevices.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final device = connectedDevices[index];
                      final assignment =
                          _session?.getChannelAssignment(device.id);

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(device.name[0].toUpperCase()),
                          ),
                          title: Text(device.name),
                          subtitle: Text(
                            '${device.model} - ${device.connectionState.name}',
                          ),
                          trailing: Chip(
                            label: Text(
                              assignment?.channel.code ?? 'STEREO',
                            ),
                            backgroundColor:
                                _getChannelColor(assignment?.channel),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _getLocalIp() {
    // The actual IP discovery happens asynchronously in SyncProtocol.
    // For now, indicate the session is active.
    return _session != null ? 'Session Active' : 'Starting...';
  }

  Color? _getChannelColor(AudioChannel? channel) {
    switch (channel) {
      case AudioChannel.left:
        return Colors.blue[100];
      case AudioChannel.right:
        return Colors.red[100];
      case AudioChannel.center:
        return Colors.green[100];
      default:
        return Colors.grey[200];
    }
  }

  @override
  void dispose() {
    _audioEngine.dispose();
    _syncProtocol.dispose();
    super.dispose();
  }
}
