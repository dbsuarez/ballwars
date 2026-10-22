import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'video_encoder.dart';

/// `window.ballwarsVideo` from `web/video_export.js`.
@JS('ballwarsVideo')
external _BallwarsVideo? get _api;

extension type _BallwarsVideo._(JSObject _) implements JSObject {
  external bool isSupported();
  external JSPromise<JSAny?> start(int width, int height, int fps);
  external JSPromise<JSAny?> addFrame(JSUint8Array rgba);
  external JSPromise<JSString> finish();
  external void cancel();
  external void download(String url, String fileName);
  external JSPromise<JSBoolean> share(String url, String fileName);
}

/// The browser backend, or null when this browser can't encode video.
VideoExportBackend? createWebVideoExport() {
  final api = _api;
  return api != null && api.isSupported() ? WebVideoExport._(api) : null;
}

/// Encodes with the browser's WebCodecs H.264 encoder into an MP4, then
/// downloads it (and can open the share sheet where the browser supports it).
class WebVideoExport implements VideoExportBackend {
  final _BallwarsVideo _video;
  final String _fileName = 'ballwars_replay_${DateTime.now().millisecondsSinceEpoch}.mp4';

  WebVideoExport._(this._video);

  @override
  Future<void> start({required int width, required int height, required int fps}) =>
      _video.start(width, height, fps).toDart;

  @override
  Future<void> addFrame(Uint8List rgba) => _video.addFrame(rgba.toJS).toDart;

  @override
  Future<String> finish() async => (await _video.finish().toDart).toDart;

  @override
  Future<void> cancel() async => _video.cancel();

  @override
  Future<String> save(String video) async {
    _video.download(video, _fileName);
    return video;
  }

  @override
  String get savedMessage => 'Downloaded $_fileName.';

  @override
  Future<void> share(String savedVideo) async {
    final shared = (await _video.share(savedVideo, _fileName).toDart).toDart;
    // Desktop browsers usually can't share files: download it again instead.
    if (!shared) _video.download(savedVideo, _fileName);
  }
}
