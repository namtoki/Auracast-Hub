import 'audio_channel.dart';

/// Represents a channel assignment for a device.
class ChannelAssignment {
  final String deviceId;
  final AudioChannel channel;
  final double? volume; // 0.0 - 1.0
  final int? delayOffsetMs; // Manual delay compensation

  const ChannelAssignment({
    required this.deviceId,
    required this.channel,
    this.volume = 1.0,
    this.delayOffsetMs = 0,
  });

  ChannelAssignment copyWith({
    String? deviceId,
    AudioChannel? channel,
    double? volume,
    int? delayOffsetMs,
  }) {
    return ChannelAssignment(
      deviceId: deviceId ?? this.deviceId,
      channel: channel ?? this.channel,
      volume: volume ?? this.volume,
      delayOffsetMs: delayOffsetMs ?? this.delayOffsetMs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'channel': channel.code,
      'volume': volume,
      'delayOffsetMs': delayOffsetMs,
    };
  }

  factory ChannelAssignment.fromJson(Map<String, dynamic> json) {
    return ChannelAssignment(
      deviceId: json['deviceId'] as String,
      channel: AudioChannel.fromCode(json['channel'] as String) ??
          AudioChannel.stereo,
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      delayOffsetMs: json['delayOffsetMs'] as int? ?? 0,
    );
  }
}
