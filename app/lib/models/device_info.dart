import 'audio_channel.dart';

/// Represents a device in the SpatialSync network.
class DeviceInfo {
  final String id;
  final String name;
  final String model;
  final String platform; // 'ios' or 'android'
  final String osVersion;
  final bool isHost;
  final DateTime? joinedAt;
  final AudioChannel? assignedChannel;
  final int? estimatedLatencyMs;
  final DeviceConnectionState connectionState;

  const DeviceInfo({
    required this.id,
    required this.name,
    required this.model,
    required this.platform,
    required this.osVersion,
    this.isHost = false,
    this.joinedAt,
    this.assignedChannel,
    this.estimatedLatencyMs,
    this.connectionState = DeviceConnectionState.disconnected,
  });

  DeviceInfo copyWith({
    String? id,
    String? name,
    String? model,
    String? platform,
    String? osVersion,
    bool? isHost,
    DateTime? joinedAt,
    AudioChannel? assignedChannel,
    int? estimatedLatencyMs,
    DeviceConnectionState? connectionState,
  }) {
    return DeviceInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      model: model ?? this.model,
      platform: platform ?? this.platform,
      osVersion: osVersion ?? this.osVersion,
      isHost: isHost ?? this.isHost,
      joinedAt: joinedAt ?? this.joinedAt,
      assignedChannel: assignedChannel ?? this.assignedChannel,
      estimatedLatencyMs: estimatedLatencyMs ?? this.estimatedLatencyMs,
      connectionState: connectionState ?? this.connectionState,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'model': model,
      'platform': platform,
      'osVersion': osVersion,
      'isHost': isHost,
      'joinedAt': joinedAt?.toIso8601String(),
      'assignedChannel': assignedChannel?.code,
      'estimatedLatencyMs': estimatedLatencyMs,
      'connectionState': connectionState.name,
    };
  }

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      model: json['model'] as String,
      platform: json['platform'] as String,
      osVersion: json['osVersion'] as String,
      isHost: json['isHost'] as bool? ?? false,
      joinedAt: json['joinedAt'] != null
          ? DateTime.parse(json['joinedAt'] as String)
          : null,
      assignedChannel: json['assignedChannel'] != null
          ? AudioChannel.fromCode(json['assignedChannel'] as String)
          : null,
      estimatedLatencyMs: json['estimatedLatencyMs'] as int?,
      connectionState: DeviceConnectionState.values.firstWhere(
        (e) => e.name == json['connectionState'],
        orElse: () => DeviceConnectionState.disconnected,
      ),
    );
  }

  @override
  String toString() =>
      'DeviceInfo(id: $id, name: $name, model: $model, channel: ${assignedChannel?.code})';
}

enum DeviceConnectionState {
  disconnected,
  connecting,
  connected,
  syncing,
  synchronized,
  error,
}
