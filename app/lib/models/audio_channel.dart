/// Audio channel types for the SpatialSync system.
enum AudioChannel {
  left('L', 'Left'),
  right('R', 'Right'),
  center('C', 'Center'),
  subwoofer('LFE', 'Subwoofer'),
  surroundLeft('SL', 'Surround Left'),
  surroundRight('SR', 'Surround Right'),
  stereo('STEREO', 'Stereo'),
  mono('MONO', 'Mono');

  const AudioChannel(this.code, this.displayName);
  final String code;
  final String displayName;

  /// Get channel mask bit for this channel.
  int get maskBit {
    switch (this) {
      case AudioChannel.left:
        return 0x01;
      case AudioChannel.right:
        return 0x02;
      case AudioChannel.center:
        return 0x04;
      case AudioChannel.subwoofer:
        return 0x08;
      case AudioChannel.surroundLeft:
        return 0x10;
      case AudioChannel.surroundRight:
        return 0x20;
      case AudioChannel.stereo:
        return 0x03; // L + R
      case AudioChannel.mono:
        return 0x07; // L + R + C mixed
    }
  }

  static AudioChannel? fromCode(String code) {
    for (final channel in AudioChannel.values) {
      if (channel.code == code) {
        return channel;
      }
    }
    return null;
  }
}
