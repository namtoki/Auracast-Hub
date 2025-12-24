import 'package:flutter/material.dart';

import '../../models/models.dart';

class ManualAssignScreen extends StatefulWidget {
  final Session session;
  final void Function(List<ChannelAssignment> assignments) onAssignmentChanged;

  const ManualAssignScreen({
    super.key,
    required this.session,
    required this.onAssignmentChanged,
  });

  @override
  State<ManualAssignScreen> createState() => _ManualAssignScreenState();
}

class _ManualAssignScreenState extends State<ManualAssignScreen> {
  late Map<String, ChannelAssignment> _assignments;

  @override
  void initState() {
    super.initState();
    _assignments = {
      for (final a in widget.session.channelAssignments) a.deviceId: a,
    };

    // Initialize unassigned devices with stereo
    for (final device in widget.session.clientDevices) {
      _assignments.putIfAbsent(
        device.id,
        () => ChannelAssignment(
          deviceId: device.id,
          channel: AudioChannel.stereo,
        ),
      );
    }
  }

  void _updateAssignment(String deviceId, AudioChannel channel) {
    setState(() {
      _assignments[deviceId] = _assignments[deviceId]!.copyWith(
        channel: channel,
      );
    });
    widget.onAssignmentChanged(_assignments.values.toList());
  }

  void _updateVolume(String deviceId, double volume) {
    setState(() {
      _assignments[deviceId] = _assignments[deviceId]!.copyWith(
        volume: volume,
      );
    });
    widget.onAssignmentChanged(_assignments.values.toList());
  }

  void _updateDelay(String deviceId, int delayMs) {
    setState(() {
      _assignments[deviceId] = _assignments[deviceId]!.copyWith(
        delayOffsetMs: delayMs,
      );
    });
    widget.onAssignmentChanged(_assignments.values.toList());
  }

  @override
  Widget build(BuildContext context) {
    final devices = widget.session.clientDevices;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Channel Assignment'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Visual Layout
          Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            child: _buildSpeakerLayout(devices),
          ),

          const Divider(),

          // Device List
          Expanded(
            child: ListView.builder(
              itemCount: devices.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final device = devices[index];
                final assignment = _assignments[device.id]!;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Device Header
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  _getChannelColor(assignment.channel),
                              child: Text(
                                assignment.channel.code,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    device.name,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  Text(
                                    device.model,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Channel Selection
                        Text(
                          'Channel',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            AudioChannel.left,
                            AudioChannel.right,
                            AudioChannel.stereo,
                            AudioChannel.mono,
                          ].map((channel) {
                            final isSelected = assignment.channel == channel;
                            return ChoiceChip(
                              label: Text(channel.displayName),
                              selected: isSelected,
                              onSelected: (_) {
                                _updateAssignment(device.id, channel);
                              },
                              selectedColor: _getChannelColor(channel),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 16),

                        // Volume Slider
                        Row(
                          children: [
                            Text(
                              'Volume',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Slider(
                                value: assignment.volume ?? 1.0,
                                min: 0.0,
                                max: 1.0,
                                divisions: 20,
                                label:
                                    '${((assignment.volume ?? 1.0) * 100).toInt()}%',
                                onChanged: (value) {
                                  _updateVolume(device.id, value);
                                },
                              ),
                            ),
                            SizedBox(
                              width: 48,
                              child: Text(
                                '${((assignment.volume ?? 1.0) * 100).toInt()}%',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),

                        // Delay Offset
                        Row(
                          children: [
                            Text(
                              'Delay',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Slider(
                                value:
                                    (assignment.delayOffsetMs ?? 0).toDouble(),
                                min: -50,
                                max: 50,
                                divisions: 20,
                                label: '${assignment.delayOffsetMs ?? 0}ms',
                                onChanged: (value) {
                                  _updateDelay(device.id, value.toInt());
                                },
                              ),
                            ),
                            SizedBox(
                              width: 48,
                              child: Text(
                                '${assignment.delayOffsetMs ?? 0}ms',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildSpeakerLayout(List<DeviceInfo> devices) {
    // Create a visual representation of speaker placement
    final leftDevices = devices
        .where((d) => _assignments[d.id]?.channel == AudioChannel.left)
        .toList();
    final rightDevices = devices
        .where((d) => _assignments[d.id]?.channel == AudioChannel.right)
        .toList();
    final centerDevices = devices
        .where((d) =>
            _assignments[d.id]?.channel == AudioChannel.center ||
            _assignments[d.id]?.channel == AudioChannel.stereo ||
            _assignments[d.id]?.channel == AudioChannel.mono)
        .toList();

    return Stack(
      children: [
        // Background
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
        ),

        // Listener position
        const Positioned(
          left: 0,
          right: 0,
          bottom: 20,
          child: Center(
            child: Column(
              children: [
                Icon(Icons.person, size: 32, color: Colors.grey),
                Text('Listener', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),

        // Left speakers
        Positioned(
          left: 20,
          top: 20,
          child: Column(
            children: [
              _buildSpeakerIcon(AudioChannel.left, leftDevices.length),
              if (leftDevices.isNotEmpty)
                Text(
                  leftDevices.map((d) => d.name).join(', '),
                  style: const TextStyle(fontSize: 10),
                ),
            ],
          ),
        ),

        // Right speakers
        Positioned(
          right: 20,
          top: 20,
          child: Column(
            children: [
              _buildSpeakerIcon(AudioChannel.right, rightDevices.length),
              if (rightDevices.isNotEmpty)
                Text(
                  rightDevices.map((d) => d.name).join(', '),
                  style: const TextStyle(fontSize: 10),
                ),
            ],
          ),
        ),

        // Center/Stereo speakers
        Positioned(
          left: 0,
          right: 0,
          top: 30,
          child: Center(
            child: Column(
              children: [
                _buildSpeakerIcon(AudioChannel.stereo, centerDevices.length),
                if (centerDevices.isNotEmpty)
                  Text(
                    centerDevices.map((d) => d.name).join(', '),
                    style: const TextStyle(fontSize: 10),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpeakerIcon(AudioChannel channel, int count) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color:
            count > 0 ? _getChannelColor(channel) : Colors.grey.withOpacity(0.3),
        shape: BoxShape.circle,
        border: Border.all(
          color: count > 0 ? Colors.black54 : Colors.grey,
          width: 2,
        ),
      ),
      child: Center(
        child: count > 0
            ? Text(
                channel.code,
                style: const TextStyle(fontWeight: FontWeight.bold),
              )
            : const Icon(Icons.speaker, color: Colors.grey),
      ),
    );
  }

  Color _getChannelColor(AudioChannel channel) {
    switch (channel) {
      case AudioChannel.left:
        return Colors.blue[100]!;
      case AudioChannel.right:
        return Colors.red[100]!;
      case AudioChannel.center:
        return Colors.green[100]!;
      case AudioChannel.stereo:
        return Colors.purple[100]!;
      case AudioChannel.mono:
        return Colors.orange[100]!;
      default:
        return Colors.grey[200]!;
    }
  }
}
