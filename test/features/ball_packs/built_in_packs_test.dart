import 'dart:convert';
import 'dart:io';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/utils/ball_image_loader.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/ball_packs/data/ball_pack_repository.dart';

/// Checks the generated packs in web/packs (see tool/build_packs.mjs).
void main() {
  final packsDir = Directory('web/packs');
  final catalog = jsonDecode(File('web/packs/packs.json').readAsStringSync()) as Map<String, dynamic>;
  final groups = (catalog['groups'] as List).cast<Map<String, dynamic>>();

  test('catalog is consistent: every image exists, ids are unique, colors parse', () {
    expect(groups.map((g) => g['id']).toSet().length, groups.length);
    for (final g in groups) {
      final balls = (g['balls'] as List).cast<Map<String, dynamic>>();
      expect(balls.length, greaterThanOrEqualTo(2), reason: '${g['name']} needs 2+ balls');
      expect(balls.map((b) => b['id']).toSet().length, balls.length, reason: 'duplicate id in ${g['name']}');
      for (final b in balls) {
        expect(File('${packsDir.path}/${b['image']}').existsSync(), isTrue, reason: b['image'] as String);
        expect(b['color'], matches(RegExp(r'^#[0-9A-F]{6}$')));
      }
    }
  });

  test('the repository turns the catalog into logo and flag balls', () async {
    final repo = BallPackRepository(
      baseUri: Uri.parse('https://example.com/app/packs/'),
      fetch: (url) async => File('web/packs/${url.pathSegments.last}').readAsString(),
    );
    final packs = await repo.load();

    expect(packs.length, groups.length);
    final netflix = packs.firstWhere((p) => p.id == 'streaming').balls.firstWhere((b) => b.name == 'Netflix');
    expect(netflix.id, 'pack:streaming/netflix');
    expect(netflix.imageUrl, 'https://example.com/app/packs/streaming/netflix.svg');
    expect(netflix.imageStyle, BallImageStyle.logo);
    expect(netflix.primaryColor, const Color(0xFFE50914));

    final ph = packs.firstWhere((p) => p.id == 'countries').balls.firstWhere((b) => b.name == 'Philippines');
    expect(ph.imageStyle, BallImageStyle.cover);
  });

  testWidgets('every pack image renders with flutter_svg', (tester) async {
    final failures = <String>[];
    var rendered = 0;
    await tester.runAsync(() async {
      for (final g in groups) {
        for (final b in (g['balls'] as List).cast<Map<String, dynamic>>()) {
          final file = File('${packsDir.path}/${b['image']}');
          try {
            final image = await BallImageLoader.renderSvg(file.readAsBytesSync());
            expect(image.width, BallImageLoader.size);
            image.dispose();
            rendered++;
          } catch (e) {
            failures.add('${b['image']}: $e');
          }
        }
      }
    });
    expect(failures, isEmpty);
    expect(rendered, greaterThan(300));
  });
}
