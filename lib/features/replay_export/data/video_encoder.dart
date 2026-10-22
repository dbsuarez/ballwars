import 'package:flutter/foundation.dart';

/// Turns raw RGBA frames into a video file.
abstract class VideoEncoder {
  Future<void> start({required int width, required int height, required int fps});

  /// One frame, `width * height * 4` bytes of RGBA.
  Future<void> addFrame(Uint8List rgba);

  /// Finishes the video and returns where it is (a file path or a URL).
  Future<String> finish();

  /// Abandons the video and discards any partial output.
  Future<void> cancel();
}

/// Where a finished video goes after encoding.
abstract class VideoSaver {
  /// Saves the video from [VideoEncoder.finish] for the user (gallery on
  /// Android, download on web) and returns a reference [share] accepts.
  Future<String> save(String video);

  /// Shown after [save], e.g. "Saved to Movies/BallWars."
  String get savedMessage;

  Future<void> share(String savedVideo);
}

/// A platform's encoder plus where its videos end up.
abstract class VideoExportBackend implements VideoEncoder, VideoSaver {}
