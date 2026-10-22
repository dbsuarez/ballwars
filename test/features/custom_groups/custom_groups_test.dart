import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/ball_management/data/local_ball_repository.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/custom_groups/data/custom_group_repository.dart';
import 'package:ballwars/features/custom_groups/data/image_prep.dart';
import 'package:ballwars/features/custom_groups/domain/custom_group.dart';
import 'package:ballwars/features/custom_groups/presentation/my_groups_screen.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/match_setup/presentation/match_setup_screen.dart';
import 'package:ballwars/features/replay_export/domain/replay_link.dart';

CustomBall _groupBall(String uuid, String name) => CustomBall(
      id: CustomGroup.ballId(uuid),
      name: name,
      imageUrl: 'https://x.supabase.co/storage/v1/object/public/ball-images/u/$uuid.png',
      imageStyle: BallImageStyle.logo,
      primaryColor: const Color(0xFF8E44AD),
      glowColor: const Color(0xFFC39BD3),
    );

class _FakeGroups implements CustomGroupRepository {
  final List<CustomGroup> groups;
  final List<Map<String, Object?>> updates = [];
  _FakeGroups(this.groups);

  @override
  Future<CustomBall> updateBall(CustomBall ball,
      {required String name, required BallImageStyle style, required Color color, Uint8List? png}) async {
    updates.add({'id': ball.id, 'name': name, 'style': style, 'color': color, 'png': png});
    return ball.copyWith(name: name, imageStyle: style, primaryColor: color);
  }

  @override
  Future<List<CustomGroup>> myGroups() async => groups;

  @override
  Future<List<CustomBall>> ballsById(List<String> ids) async =>
      [for (final g in groups) for (final b in g.balls) if (ids.contains(b.id)) b];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  test('group balls travel in links as g.<uuid> and resolve from the group store', () {
    final ball = _groupBall('0b7c', 'Goku');
    final uri = ReplayLink(seed: 9, speedMultiplier: 1, contestants: [ball, LocalBallRepository.presets[0]])
        .toUri(presetIds: {for (final b in LocalBallRepository.presets) b.id}, appUrl: kWebAppUrl);

    expect(uri.toString(), contains('balls=g.0b7c,p.preset-usa'));
    expect(ReplayLink.groupBallIds(uri), ['group:0b7c']);
    expect(ReplayLink.fromUri(uri, presets: LocalBallRepository.presets), isNull);
    final parsed = ReplayLink.fromUri(uri, presets: LocalBallRepository.presets, packBalls: {ball.id: ball})!;
    expect(parsed.contestants.first, same(ball));
  });

  test('the suggested color is the most common vivid color, ignoring white and transparent', () {
    final rgba = Uint8List(64 * 64 * 4);
    for (var i = 0; i < 64 * 64; i++) {
      final o = i * 4;
      if (i % 4 == 0) {
        rgba.setAll(o, [255, 255, 255, 255]); // white background
      } else if (i % 4 == 1) {
        rgba.setAll(o, [0, 0, 0, 0]); // transparent
      } else {
        rgba.setAll(o, [200, 30, 40, 255]); // red logo
      }
    }
    final color = ImagePrep.dominantColor(rgba);
    expect((color.r * 255).round(), closeTo(200, 16));
    expect((color.g * 255).round(), closeTo(30, 16));
    expect((color.b * 255).round(), closeTo(40, 16));
  });

  testWidgets('my groups show up as categories in Match Setup', (tester) async {
    MatchConfig? started;
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: MatchSetupScreen(
        customGroups: _FakeGroups([
          CustomGroup(id: 'g1', name: 'Anime', isPublic: true, balls: [_groupBall('a', 'Goku'), _groupBall('b', 'Luffy')]),
          const CustomGroup(id: 'g2', name: 'Empty group', isPublic: true, balls: []),
        ]),
        onStartBattle: (c) => started = c,
      ),
    ));
    await tester.pumpAndSettle();

    // The first group with balls opens by default.
    expect(find.text('Goku'), findsOneWidget);
    await tester.tap(find.byType(DropdownMenu<String>));
    await tester.pumpAndSettle();
    expect(find.text('Empty group'), findsNothing); // nothing to pick from
    await tester.tapAt(const Offset(5, 5)); // close the menu
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.shuffle));
    await tester.pump();
    await tester.tap(find.text('Start'));
    expect(started!.contestants.map((b) => b.name).toSet(), {'Goku', 'Luffy'});
  });

  testWidgets('tapping a ball in My Groups opens it for editing; saving without a new picture keeps it', (tester) async {
    final repo = _FakeGroups([
      CustomGroup(id: 'g1', name: 'Anime', isPublic: true, balls: [_groupBall('a', 'Goku')]),
    ]);
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: MyGroupsScreen(repository: repo)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Goku'));
    await tester.pumpAndSettle();
    expect(find.text('Edit ball'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Goku'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Son Goku');
    await tester.tap(find.text('Fill the ball'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.updates, hasLength(1));
    expect(repo.updates.single['id'], 'group:a');
    expect(repo.updates.single['name'], 'Son Goku');
    expect(repo.updates.single['style'], BallImageStyle.cover);
    expect(repo.updates.single['color'], const Color(0xFF8E44AD)); // kept
    expect(repo.updates.single['png'], isNull); // picture unchanged
    expect(find.text('Edit ball'), findsNothing);
  });
}
