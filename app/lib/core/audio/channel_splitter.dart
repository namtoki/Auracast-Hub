import 'dart:typed_data';

import '../../models/audio_channel.dart';

/// Splits stereo or multichannel audio into separate channel streams.
class ChannelSplitter {
  final int channelCount;
  final int bytesPerSample;

  ChannelSplitter({
    this.channelCount = 2,
    this.bytesPerSample = 2, // 16-bit = 2 bytes
  });

  /// Split interleaved audio data into separate channels.
  Map<AudioChannel, Uint8List> split(Uint8List interleavedData) {
    final samplesPerChannel = interleavedData.length ~/ (channelCount * bytesPerSample);
    final result = <AudioChannel, Uint8List>{};

    if (channelCount == 2) {
      // Stereo: L R L R L R ...
      final leftData = Uint8List(samplesPerChannel * bytesPerSample);
      final rightData = Uint8List(samplesPerChannel * bytesPerSample);

      for (var i = 0; i < samplesPerChannel; i++) {
        final srcOffset = i * channelCount * bytesPerSample;
        final dstOffset = i * bytesPerSample;

        // Copy left sample
        for (var b = 0; b < bytesPerSample; b++) {
          leftData[dstOffset + b] = interleavedData[srcOffset + b];
        }

        // Copy right sample
        for (var b = 0; b < bytesPerSample; b++) {
          rightData[dstOffset + b] = interleavedData[srcOffset + bytesPerSample + b];
        }
      }

      result[AudioChannel.left] = leftData;
      result[AudioChannel.right] = rightData;
    }

    return result;
  }

  /// Extract a specific channel from interleaved data.
  Uint8List extractChannel(Uint8List interleavedData, int channelIndex) {
    if (channelIndex >= channelCount) {
      throw ArgumentError('Channel index out of range');
    }

    final samplesPerChannel = interleavedData.length ~/ (channelCount * bytesPerSample);
    final result = Uint8List(samplesPerChannel * bytesPerSample);

    for (var i = 0; i < samplesPerChannel; i++) {
      final srcOffset = (i * channelCount + channelIndex) * bytesPerSample;
      final dstOffset = i * bytesPerSample;

      for (var b = 0; b < bytesPerSample; b++) {
        result[dstOffset + b] = interleavedData[srcOffset + b];
      }
    }

    return result;
  }

  /// Mix specified channels from interleaved data.
  Uint8List mixChannels(
    Uint8List interleavedData,
    List<int> channelIndices, {
    List<double>? gains,
  }) {
    if (channelIndices.any((i) => i >= channelCount)) {
      throw ArgumentError('Channel index out of range');
    }

    final effectiveGains = gains ?? List.filled(channelIndices.length, 1.0);
    if (effectiveGains.length != channelIndices.length) {
      throw ArgumentError('Gains length must match channel indices length');
    }

    final samplesPerChannel = interleavedData.length ~/ (channelCount * bytesPerSample);
    final result = Uint8List(samplesPerChannel * bytesPerSample);
    final view = ByteData.sublistView(result);
    final srcView = ByteData.sublistView(interleavedData);

    for (var i = 0; i < samplesPerChannel; i++) {
      var mixedSample = 0.0;

      for (var c = 0; c < channelIndices.length; c++) {
        final srcOffset = (i * channelCount + channelIndices[c]) * bytesPerSample;
        final sample = srcView.getInt16(srcOffset, Endian.little);
        mixedSample += sample * effectiveGains[c];
      }

      // Clamp to 16-bit range
      final clampedSample = mixedSample.clamp(-32768, 32767).toInt();
      view.setInt16(i * bytesPerSample, clampedSample, Endian.little);
    }

    return result;
  }

  /// Create mono downmix from stereo.
  Uint8List toMono(Uint8List stereoData) {
    if (channelCount != 2) {
      throw StateError('toMono only works with stereo input');
    }

    return mixChannels(stereoData, [0, 1], gains: [0.5, 0.5]);
  }
}
