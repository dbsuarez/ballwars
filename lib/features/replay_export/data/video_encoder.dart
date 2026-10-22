import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Turns raw RGBA frames into a video file.
abstract class VideoEncoder {
  Future<void> start({required int width, required int height, required int fps});

  /// One frame, `width * height * 4` bytes of RGBA.
  Future<void> addFrame(Uint8List rgba);

  /// Finishes the file and returns its local path.
  Future<String> finish();

  /// Abandons the video and deletes any partial file.
  Future<void> cancel();
}

/// Where a finished video can go after encoding.
abstract class VideoSaver {
  /// Copies the video at [path] into the device gallery and returns a
  /// reference that [share] accepts.
  Future<String> saveToGallery(String path);

  Future<void> share(String savedVideo);
}

/// H.264/MP4 encoding with the device's own encoder (Android MediaCodec),
/// implemented in `android/app/src/main/kotlin/.../MainActivity.kt`.
class PlatformVideoEncoder implements VideoEncoder, VideoSaver {
  static const MethodChannel _channel = MethodChannel('ballwars/video_export');

  /// Only Android has a native encoder so far.
  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

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
  Future<String> saveToGallery(String path) async =>
      (await _channel.invokeMethod<String>('saveToGallery', {'path': path}))!;

  @override
  Future<void> share(String savedVideo) => _channel.invokeMethod('share', {'uri': savedVideo});
}
