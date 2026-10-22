import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/replay_export/application/replay_video_exporter.dart';
import 'package:ballwars/features/replay_export/data/video_encoder.dart';

/// Runs on a real Android device: `flutter test integration_test -d <device>`.
/// Encodes a full replay with the device's encoder and checks the MP4.
/// Writes only to the app cache unless KEEP_VIDEO is set (see below).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('exports a replay as an MP4 with the device encoder', (tester) async {
    final stopwatch = Stopwatch()..start();
    late String path;
    await tester.runAsync(() async {
      path = await ReplayVideoExporter(encoder: PlatformVideoEncoder()).export(
        contestants: const [
          CustomBall(id: 'a', name: 'A', primaryColor: Colors.red, glowColor: Colors.pink),
          CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan),
        ],
        seed: 4,
        arenaRadius: 260,
      );
    });
    stopwatch.stop();

    final file = File(path);
    final bytes = await file.readAsBytes();
    // ignore: avoid_print
    print('VIDEO_EXPORT: ${bytes.length} bytes in ${stopwatch.elapsed.inMilliseconds} ms at $path');
    expect(bytes.length, greaterThan(10000));
    // MP4: the first box is 'ftyp', and the file has a 'moov' (index) box.
    expect(String.fromCharCodes(bytes.sublist(4, 8)), 'ftyp');
    expect(String.fromCharCodes(bytes).contains('moov'), isTrue);
    // --dart-define=KEEP_VIDEO=true saves it to the gallery (Movies/BallWars)
    // instead, so it survives the test uninstalling the app.
    if (const bool.fromEnvironment('KEEP_VIDEO')) {
      final saved = await PlatformVideoEncoder().saveToGallery(path);
      // ignore: avoid_print
      print('VIDEO_SAVED: $saved');
    } else {
      await file.delete();
    }
  });
}
