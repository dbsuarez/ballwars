import 'video_encoder.dart';

/// Non-web builds have no browser encoder.
VideoExportBackend? createWebVideoExport() => null;
