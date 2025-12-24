import 'audio_channel.dart';

/// User settings persisted to AWS DynamoDB.
class UserSettings {
  final String userId;
  final String? preferredDeviceName;
  final AudioChannel defaultChannel;
  final int bufferSizeMs;
  final bool autoCalibrate;
  final bool showAdvancedOptions;
  final DeviceProfile? deviceProfile;
  final DateTime? lastUpdated;

  const UserSettings({
    required this.userId,
    this.preferredDeviceName,
    this.defaultChannel = AudioChannel.stereo,
    this.bufferSizeMs = 100,
    this.autoCalibrate = true,
    this.showAdvancedOptions = false,
    this.deviceProfile,
    this.lastUpdated,
  });

  UserSettings copyWith({
    String? userId,
    String? preferredDeviceName,
    AudioChannel? defaultChannel,
    int? bufferSizeMs,
    bool? autoCalibrate,
    bool? showAdvancedOptions,
    DeviceProfile? deviceProfile,
    DateTime? lastUpdated,
  }) {
    return UserSettings(
      userId: userId ?? this.userId,
      preferredDeviceName: preferredDeviceName ?? this.preferredDeviceName,
      defaultChannel: defaultChannel ?? this.defaultChannel,
      bufferSizeMs: bufferSizeMs ?? this.bufferSizeMs,
      autoCalibrate: autoCalibrate ?? this.autoCalibrate,
      showAdvancedOptions: showAdvancedOptions ?? this.showAdvancedOptions,
      deviceProfile: deviceProfile ?? this.deviceProfile,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'preferredDeviceName': preferredDeviceName,
      'defaultChannel': defaultChannel.code,
      'bufferSizeMs': bufferSizeMs,
      'autoCalibrate': autoCalibrate,
      'showAdvancedOptions': showAdvancedOptions,
      'deviceProfile': deviceProfile?.toJson(),
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      userId: json['userId'] as String,
      preferredDeviceName: json['preferredDeviceName'] as String?,
      defaultChannel:
          AudioChannel.fromCode(json['defaultChannel'] as String? ?? 'STEREO') ??
              AudioChannel.stereo,
      bufferSizeMs: json['bufferSizeMs'] as int? ?? 100,
      autoCalibrate: json['autoCalibrate'] as bool? ?? true,
      showAdvancedOptions: json['showAdvancedOptions'] as bool? ?? false,
      deviceProfile: json['deviceProfile'] != null
          ? DeviceProfile.fromJson(
              json['deviceProfile'] as Map<String, dynamic>)
          : null,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : null,
    );
  }
}

/// Device-specific profile with measured latency characteristics.
class DeviceProfile {
  final String deviceId;
  final String model;
  final String platform;
  final String osVersion;
  final int measuredOutputLatencyMs;
  final int measuredInputLatencyMs;
  final int recommendedBufferMs;
  final DateTime createdAt;
  final int measurementCount;

  const DeviceProfile({
    required this.deviceId,
    required this.model,
    required this.platform,
    required this.osVersion,
    this.measuredOutputLatencyMs = 0,
    this.measuredInputLatencyMs = 0,
    this.recommendedBufferMs = 100,
    required this.createdAt,
    this.measurementCount = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'model': model,
      'platform': platform,
      'osVersion': osVersion,
      'measuredOutputLatencyMs': measuredOutputLatencyMs,
      'measuredInputLatencyMs': measuredInputLatencyMs,
      'recommendedBufferMs': recommendedBufferMs,
      'createdAt': createdAt.toIso8601String(),
      'measurementCount': measurementCount,
    };
  }

  factory DeviceProfile.fromJson(Map<String, dynamic> json) {
    return DeviceProfile(
      deviceId: json['deviceId'] as String,
      model: json['model'] as String,
      platform: json['platform'] as String,
      osVersion: json['osVersion'] as String,
      measuredOutputLatencyMs: json['measuredOutputLatencyMs'] as int? ?? 0,
      measuredInputLatencyMs: json['measuredInputLatencyMs'] as int? ?? 0,
      recommendedBufferMs: json['recommendedBufferMs'] as int? ?? 100,
      createdAt: DateTime.parse(json['createdAt'] as String),
      measurementCount: json['measurementCount'] as int? ?? 0,
    );
  }
}
