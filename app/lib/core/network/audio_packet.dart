import 'dart:typed_data';

/// Audio packet format for SpatialSync streaming.
///
/// Format:
/// - Magic: 4 bytes "SSYN"
/// - Version: 1 byte
/// - SeqNum: 4 bytes
/// - PlayTime: 8 bytes (microseconds)
/// - ChannelMask: 1 byte
/// - PayloadLength: 2 bytes
/// - Payload: Variable (Opus or PCM data)
class AudioPacket {
  static const int headerSize = 20;
  static const int magic = 0x5353594E; // "SSYN"
  static const int version = 1;

  final int sequenceNumber;
  final int playTimeUs; // When this audio should be played (host time)
  final int channelMask; // Which channels this packet contains
  final Uint8List payload;

  const AudioPacket({
    required this.sequenceNumber,
    required this.playTimeUs,
    required this.channelMask,
    required this.payload,
  });

  /// Serialize packet to bytes.
  Uint8List toBytes() {
    final buffer = Uint8List(headerSize + payload.length);
    final view = ByteData.sublistView(buffer);

    view.setUint32(0, magic);
    view.setUint8(4, version);
    view.setUint32(5, sequenceNumber);
    view.setInt64(9, playTimeUs);
    view.setUint8(17, channelMask);
    view.setUint16(18, payload.length);
    buffer.setRange(headerSize, headerSize + payload.length, payload);

    return buffer;
  }

  /// Parse packet from bytes.
  static AudioPacket? fromBytes(Uint8List data) {
    if (data.length < headerSize) return null;

    final view = ByteData.sublistView(data);

    final packetMagic = view.getUint32(0);
    if (packetMagic != magic) return null;

    final packetVersion = view.getUint8(4);
    if (packetVersion != version) return null;

    final sequenceNumber = view.getUint32(5);
    final playTimeUs = view.getInt64(9);
    final channelMask = view.getUint8(17);
    final payloadLength = view.getUint16(18);

    if (data.length < headerSize + payloadLength) return null;

    final payload = Uint8List.sublistView(
      data,
      headerSize,
      headerSize + payloadLength,
    );

    return AudioPacket(
      sequenceNumber: sequenceNumber,
      playTimeUs: playTimeUs,
      channelMask: channelMask,
      payload: payload,
    );
  }

  /// Calculate delay until this packet should be played.
  int delayUntilPlayUs(int currentSyncedTimeUs) {
    return playTimeUs - currentSyncedTimeUs;
  }

  @override
  String toString() =>
      'AudioPacket(seq: $sequenceNumber, playTime: $playTimeUs, channels: 0x${channelMask.toRadixString(16)}, size: ${payload.length})';
}

/// Control packet for channel assignment.
/// Format:
/// - Magic: 4 bytes "CHAN"
/// - ChannelMask: 1 byte (assigned channel for this client)
/// - Volume: 1 byte (0-100)
/// - DelayMs: 2 bytes (signed, delay offset)
class ChannelAssignmentPacket {
  static const int magic = 0x4348414E; // "CHAN"
  static const int packetSize = 8;

  final int channelMask;
  final int volume; // 0-100
  final int delayMs;

  const ChannelAssignmentPacket({
    required this.channelMask,
    this.volume = 100,
    this.delayMs = 0,
  });

  Uint8List toBytes() {
    final buffer = Uint8List(packetSize);
    final view = ByteData.sublistView(buffer);

    view.setUint32(0, magic);
    view.setUint8(4, channelMask);
    view.setUint8(5, volume);
    view.setInt16(6, delayMs);

    return buffer;
  }

  static ChannelAssignmentPacket? fromBytes(Uint8List data) {
    if (data.length < packetSize) return null;

    final view = ByteData.sublistView(data);

    final packetMagic = view.getUint32(0);
    if (packetMagic != magic) return null;

    return ChannelAssignmentPacket(
      channelMask: view.getUint8(4),
      volume: view.getUint8(5),
      delayMs: view.getInt16(6),
    );
  }

  @override
  String toString() =>
      'ChannelAssignmentPacket(channel: 0x${channelMask.toRadixString(16)}, volume: $volume%, delay: ${delayMs}ms)';
}
