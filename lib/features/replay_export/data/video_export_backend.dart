import 'package:flutter/foundation.dart';
import 'android_video_export.dart';
import 'video_encoder.dart';
import 'web_video_export_stub.dart' if (dart.library.js_interop) 'web_video_export.dart';

/// The video export for this platform, or null where none exists yet
/// (iOS, desktop, or a browser without WebCodecs).
VideoExportBackend? createVideoExportBackend() {
  if (kIsWeb) return createWebVideoExport();
  if (defaultTargetPlatform == TargetPlatform.android) return AndroidVideoExport();
  return null;
}
