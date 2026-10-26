import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';

class ReplaySoundEvent {
  const ReplaySoundEvent(this.seconds, this.cue, [this.gain = 1]);

  final double seconds;
  final String cue;
  final double gain;
}

class ReplayAudio {
  const ReplayAudio(this.pcm16le, this.sampleRate);

  final Uint8List pcm16le;
  final int sampleRate;
}

/// Deterministically mixes the selected match music and replay sound events.
/// Source WAVs may have different rates/channel counts; they are converted to
/// mono at [sampleRate] before being handed to the platform MP4 encoder.
class ReplayAudioMixer {
  static const int sampleRate = 22050;

  static Future<ReplayAudio> mix({
    required double durationSeconds,
    required bool includeBgm,
    required bool includeSfx,
    required String bgmAsset,
    required double bgmLevel,
    required double sfxLevel,
    required List<ReplaySoundEvent> events,
  }) async {
    final count = math.max(1, (durationSeconds * sampleRate).ceil());
    final mix = Float32List(count);
    if (includeBgm) {
      final bgm = await _load(bgmAsset);
      for (var i = 0; i < count; i++) {
        mix[i] += bgm.sampleAt(i, sampleRate) * 0.30 * bgmLevel;
      }
    }
    if (includeSfx) {
      final cache = <String, _Wave>{};
      for (final event in events) {
        final wave = cache[event.cue] ??= await _load(
          'assets/sounds/${event.cue}.wav',
        );
        final start = (event.seconds * sampleRate).round();
        final length = (wave.frames * sampleRate / wave.sampleRate).ceil();
        for (var i = 0; i < length && start + i < count; i++) {
          if (start + i < 0) continue;
          mix[start + i] +=
              wave.sampleAt(i, sampleRate) * event.gain * sfxLevel;
        }
      }
    }
    final out = ByteData(count * 2);
    for (var i = 0; i < count; i++) {
      final clipped = mix[i].clamp(-1.0, 1.0);
      out.setInt16(i * 2, (clipped * 32767).round(), Endian.little);
    }
    return ReplayAudio(out.buffer.asUint8List(), sampleRate);
  }

  static Future<_Wave> _load(String asset) async {
    final data = await rootBundle.load(asset);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    if (bytes.length < 44 || _ascii(bytes, 0, 4) != 'RIFF') {
      throw FormatException('Unsupported WAV asset: $asset');
    }
    final view = ByteData.sublistView(bytes);
    var channels = 1;
    var rate = sampleRate;
    var bits = 16;
    var dataOffset = -1;
    var dataLength = 0;
    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final id = _ascii(bytes, offset, 4);
      final length = view.getUint32(offset + 4, Endian.little);
      final body = offset + 8;
      if (id == 'fmt ' && length >= 16) {
        if (view.getUint16(body, Endian.little) != 1) {
          throw FormatException('Only PCM WAV is supported: $asset');
        }
        channels = view.getUint16(body + 2, Endian.little);
        rate = view.getUint32(body + 4, Endian.little);
        bits = view.getUint16(body + 14, Endian.little);
      } else if (id == 'data') {
        dataOffset = body;
        dataLength = math.min(length, bytes.length - body);
        break;
      }
      offset = body + length + (length.isOdd ? 1 : 0);
    }
    if (dataOffset < 0 || bits != 16 || channels < 1) {
      throw FormatException('Unsupported WAV layout: $asset');
    }
    return _Wave(bytes, dataOffset, dataLength, rate, channels);
  }

  static String _ascii(Uint8List bytes, int start, int length) =>
      String.fromCharCodes(bytes.sublist(start, start + length));
}

class _Wave {
  const _Wave(
    this.bytes,
    this.offset,
    this.length,
    this.sampleRate,
    this.channels,
  );

  final Uint8List bytes;
  final int offset;
  final int length;
  final int sampleRate;
  final int channels;

  int get frames => length ~/ (channels * 2);

  double sampleAt(int outputFrame, int outputRate) {
    if (frames == 0) return 0;
    final sourceFrame = ((outputFrame * sampleRate) ~/ outputRate) % frames;
    final view = ByteData.sublistView(bytes);
    var sum = 0;
    for (var channel = 0; channel < channels; channel++) {
      sum += view.getInt16(
        offset + (sourceFrame * channels + channel) * 2,
        Endian.little,
      );
    }
    return sum / channels / 32768;
  }
}
