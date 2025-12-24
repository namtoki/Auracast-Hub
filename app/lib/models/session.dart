import 'device_info.dart';
import 'channel_assignment.dart';

/// Represents an active audio sync session.
class Session {
  final String id;
  final String hostDeviceId;
  final String? name;
  final DateTime createdAt;
  final SessionState state;
  final List<DeviceInfo> devices;
  final List<ChannelAssignment> channelAssignments;
  final SessionAudioConfig audioConfig;
  final int bufferSizeMs;

  const Session({
    required this.id,
    required this.hostDeviceId,
    this.name,
    required this.createdAt,
    this.state = SessionState.idle,
    this.devices = const [],
    this.channelAssignments = const [],
    this.audioConfig = const SessionAudioConfig(),
    this.bufferSizeMs = 100,
  });

  /// Get the host device.
  DeviceInfo? get hostDevice {
    try {
      return devices.firstWhere((d) => d.id == hostDeviceId);
    } catch (_) {
      return null;
    }
  }

  /// Get client devices (non-host).
  List<DeviceInfo> get clientDevices {
    return devices.where((d) => d.id != hostDeviceId).toList();
  }

  /// Get channel assignment for a device.
  ChannelAssignment? getChannelAssignment(String deviceId) {
    try {
      return channelAssignments.firstWhere((a) => a.deviceId == deviceId);
    } catch (_) {
      return null;
    }
  }

  Session copyWith({
    String? id,
    String? hostDeviceId,
    String? name,
    DateTime? createdAt,
    SessionState? state,
    List<DeviceInfo>? devices,
    List<ChannelAssignment>? channelAssignments,
    SessionAudioConfig? audioConfig,
    int? bufferSizeMs,
  }) {
    return Session(
      id: id ?? this.id,
      hostDeviceId: hostDeviceId ?? this.hostDeviceId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      state: state ?? this.state,
      devices: devices ?? this.devices,
      channelAssignments: channelAssignments ?? this.channelAssignments,
      audioConfig: audioConfig ?? this.audioConfig,
      bufferSizeMs: bufferSizeMs ?? this.bufferSizeMs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hostDeviceId': hostDeviceId,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'state': state.name,
      'devices': devices.map((d) => d.toJson()).toList(),
      'channelAssignments': channelAssignments.map((a) => a.toJson()).toList(),
      'audioConfig': audioConfig.toJson(),
      'bufferSizeMs': bufferSizeMs,
    };
  }

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as String,
      hostDeviceId: json['hostDeviceId'] as String,
      name: json['name'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      state: SessionState.values.firstWhere(
        (e) => e.name == json['state'],
        orElse: () => SessionState.idle,
      ),
      devices: (json['devices'] as List<dynamic>?)
              ?.map((d) => DeviceInfo.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      channelAssignments: (json['channelAssignments'] as List<dynamic>?)
              ?.map(
                  (a) => ChannelAssignment.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      audioConfig: json['audioConfig'] != null
          ? SessionAudioConfig.fromJson(
              json['audioConfig'] as Map<String, dynamic>)
          : const SessionAudioConfig(),
      bufferSizeMs: json['bufferSizeMs'] as int? ?? 100,
    );
  }
}

enum SessionState {
  idle,
  discovering,
  connecting,
  calibrating,
  playing,
  paused,
  error,
}

/// Audio configuration for a session.
class SessionAudioConfig {
  final int sampleRate;
  final int channelCount;
  final int bitDepth;
  final String codec; // 'opus' or 'pcm'
  final int opusBitrate;

  const SessionAudioConfig({
    this.sampleRate = 48000,
    this.channelCount = 2,
    this.bitDepth = 16,
    this.codec = 'opus',
    this.opusBitrate = 128000,
  });

  Map<String, dynamic> toJson() {
    return {
      'sampleRate': sampleRate,
      'channelCount': channelCount,
      'bitDepth': bitDepth,
      'codec': codec,
      'opusBitrate': opusBitrate,
    };
  }

  factory SessionAudioConfig.fromJson(Map<String, dynamic> json) {
    return SessionAudioConfig(
      sampleRate: json['sampleRate'] as int? ?? 48000,
      channelCount: json['channelCount'] as int? ?? 2,
      bitDepth: json['bitDepth'] as int? ?? 16,
      codec: json['codec'] as String? ?? 'opus',
      opusBitrate: json['opusBitrate'] as int? ?? 128000,
    );
  }
}
