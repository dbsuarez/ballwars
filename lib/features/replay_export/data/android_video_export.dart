import 'package:flutter/services.dart';
import 'video_encoder.dart';

/// H.264/MP4 encoding with the device's own encoder (Android MediaCodec),
/// implemented in `android/app/src/main/kotlin/.../MainActivity.kt`.
class AndroidVideoExport implements VideoExportBackend {
  static const MethodChannel _channel = MethodChannel('ballwars/video_export');

  @override
  Future<void> start({required int width, required int height, required int fps}) =>
      _channel.invokeMethod('start', {'width': width, 'height': height, 'fps': fps});

  @override
  Future<void> addFrame(Uint8List rgba) => _channel.invokeMethod('addFrame', {'rgba': rgba});

  @override
  Future<String> finish() async => (await _channel.invokeMethod<String>('finish'))!;

  @override
  Future<void> cancel() => _channel.invokeMethod('cancel');

  @override
  Future<String> save(String video) async =>
      (await _channel.invokeMethod<String>('saveToGallery', {'path': video}))!;

  @override
  String get savedMessage => 'Saved to Movies/BallWars.';

  @override
  Future<void> share(String savedVideo) => _channel.invokeMethod('share', {'uri': savedVideo});
}
