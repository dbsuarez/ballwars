import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import '../../features/ball_management/domain/custom_ball.dart';
import '../offline/offline_store.dart';
import 'canvas_image_helper.dart';

/// Loads a ball's picture as a square [ui.Image] for the canvas painters and
/// widgets: uploaded bytes, or an online PNG/JPEG/SVG (built-in pack logos and
/// flags). SVGs are drawn at [size] px with flutter_svg. Downloads are kept in
/// [OfflineStore] (the startup sync fills it in advance), and decoded images
/// are cached for the app's lifetime.
class BallImageLoader {
  BallImageLoader._();

  static const int size = 256;
  static final Map<String, Future<ui.Image?>> _cache = {};

  /// Downloads one image (also used by OfflineSync); overridable for tests.
  static Future<Uint8List> Function(Uri url) fetch = _httpFetch;

  /// The ball's image, or null when it has none or it can't be loaded (the
  /// ball then shows its color and initial instead).
  static Future<ui.Image?> load(CustomBall ball) {
    final bytes = ball.imageBytes;
    if (bytes != null) {
      return _cache.putIfAbsent('bytes:${ball.id}:${bytes.length}:${Object.hashAll(bytes.take(64))}',
          () => _guard(() => CanvasImageHelper.decode(bytes)));
    }
    final url = ball.imageUrl;
    if (url == null) return Future.value(null);
    return _cache.putIfAbsent(url, () => _guard(() => _loadUrl(Uri.parse(url))));
  }

  @visibleForTesting
  static void clearCache() => _cache.clear();

  static Future<ui.Image?> _guard(Future<ui.Image> Function() load) async {
    try {
      return await load();
    } catch (e) {
      debugPrint('BallImageLoader: $e');
      return null;
    }
  }

  static Future<ui.Image> _loadUrl(Uri url) async {
    final store = OfflineStore.instance;
    var bytes = await store.read(url.toString());
    if (bytes == null) {
      bytes = await fetch(url);
      await store.write(url.toString(), bytes);
    }
    if (!url.path.toLowerCase().endsWith('.svg')) return CanvasImageHelper.decode(bytes);
    return renderSvg(bytes);
  }

  /// Draws SVG [bytes] centered and fitted (aspect kept) into a transparent
  /// [size] x [size] image.
  static Future<ui.Image> renderSvg(Uint8List bytes) async {
    final info = await vg.loadPicture(SvgBytesLoader(bytes), null);
    try {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final w = info.size.width, h = info.size.height;
      if (w > 0 && h > 0) {
        final scale = size / (w > h ? w : h);
        canvas.translate((size - w * scale) / 2, (size - h * scale) / 2);
        canvas.scale(scale);
      }
      canvas.drawPicture(info.picture);
      final picture = recorder.endRecording();
      try {
        return await picture.toImage(size, size);
      } finally {
        picture.dispose();
      }
    } finally {
      info.picture.dispose();
    }
  }

  static Future<Uint8List> _httpFetch(Uri url) async {
    final res = await http.get(url);
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode} for $url');
    return res.bodyBytes;
  }
}
