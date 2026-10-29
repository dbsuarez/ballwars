import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import '../../tools/performance/profile_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'six-ball simulation and raster profile',
    () async {
      final report = await runSixBallProfile();
      debugPrint('BALLWARS_PROFILE ${jsonEncode(report)}');
      expect(report['peak_projectiles'] as int, greaterThan(0));
      expect(report['peak_sources'] as int, greaterThan(0));
      expect(report['balls'], 6);
      expect(report['raster_frames'], 120);
    },
    skip: !const bool.fromEnvironment('PROFILE_SIX_BALL'),
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
