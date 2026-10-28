import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/features/ball_management/data/local_ball_repository.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/ball_packs/data/ball_pack_repository.dart';
import 'package:ballwars/features/custom_groups/data/custom_group_repository.dart';
import 'package:ballwars/features/custom_groups/data/image_prep.dart';
import 'package:ballwars/features/custom_groups/domain/custom_group.dart';
import 'package:ballwars/features/custom_groups/presentation/ball_editor_sheet.dart';
import 'package:ballwars/features/custom_groups/presentation/my_groups_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/match_setup/presentation/match_setup_screen.dart';
import 'package:ballwars/features/replay_export/domain/replay_link.dart';

CustomBall _groupBall(String uuid, String name) => CustomBall(
  id: CustomGroup.ballId(uuid),
  name: name,
  imageUrl:
      'https://x.supabase.co/storage/v1/object/public/ball-images/u/$uuid.png',
  imageStyle: BallImageStyle.logo,
  primaryColor: const Color(0xFF8E44AD),
  glowColor: const Color(0xFFC39BD3),
);

class _FakeGroups implements CustomGroupRepository {
  final List<CustomGroup> groups;
  final List<CustomGroup> saved;
  final List<Map<String, Object?>> updates = [];
  final List<String> unsaved = [];
  final List<CustomGroup> extras;
  final Map<String, String?> links = {};
  final Map<String, bool> submissions = {};
  final String? id;
  int myGroupsCalls = 0;
  _FakeGroups(
    this.groups, {
    this.saved = const [],
    this.extras = const [],
    this.id = 'me',
  });

  @override
  Future<List<CustomGroup>> allGroups() async => groups;

  @override
  Future<List<CustomGroup>> packExtras() async => extras;

  @override
  Future<void> linkToPack(String groupId, String? packId) async =>
      links[groupId] = packId;

  @override
  Future<Set<String>> submittedGroupIds() async => {
    for (final e in submissions.entries)
      if (e.value) e.key,
  };

  @override
  Future<void> setSubmitted(String groupId, bool submitted) async =>
      submissions[groupId] = submitted;

  @override
  Future<List<CustomGroup>> savedGroups() async => saved;

  @override
  Future<void> unsaveGroup(String groupId) async => unsaved.add(groupId);

  @override
  String? get userId => id;

  @override
  Future<CustomBall> updateBall(
    CustomBall ball, {
    required String name,
    required BallImageStyle style,
    required Color color,
    BallGender gender = BallGender.none,
    Uint8List? png,
  }) async {
    updates.add({
      'id': ball.id,
      'name': name,
      'style': style,
      'color': color,
      'gender': gender,
      'png': png,
    });
    return ball.copyWith(
      name: name,
      imageStyle: style,
      primaryColor: color,
      gender: gender,
    );
  }

  final List<Map<String, Object?>> added = [];

  @override
  Future<CustomBall> addBall({
    required String groupId,
    required String name,
    required Uint8List? png,
    required BallImageStyle style,
    required Color color,
    BallGender gender = BallGender.none,
  }) async {
    added.add({'group': groupId, 'name': name, 'gender': gender});
    return CustomBall(
      id: CustomGroup.ballId('new'),
      name: name,
      imageStyle: style,
      primaryColor: color,
      glowColor: color,
      gender: gender,
    );
  }

  @override
  Future<List<CustomGroup>> myGroups() async {
    myGroupsCalls++;
    return groups;
  }

  @override
  Future<List<CustomBall>> ballsById(List<String> ids) async => [
    for (final g in groups)
      for (final b in g.balls)
        if (ids.contains(b.id)) b,
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  // Match Setup remembers choices (e.g. the category filter) on the device.
  setUp(() => OfflineStore.instance = MemoryOfflineStore());

  test(
    'account groups replace device groups and adopt the device groups once',
    () async {
      final device = _FakeGroups([
        const CustomGroup(
          id: 'device',
          name: 'Device',
          isPublic: true,
          balls: [],
        ),
      ], id: 'device-user');
      final account = _FakeGroups([
        const CustomGroup(
          id: 'account',
          name: 'Account',
          isPublic: true,
          balls: [],
        ),
      ], id: 'account-user');
      final adopted = <String>[];
      final repository = AccountAwareCustomGroupRepository(
        device: device,
        account: account,
        isAccountActive: () async => true,
        adoptGroupsFrom: (owner) async {
          adopted.add(owner);
          return 1;
        },
      );

      expect((await repository.myGroups()).single.id, 'account');
      expect((await repository.myGroups()).single.id, 'account');
      expect(adopted, ['device-user']);
      expect(device.myGroupsCalls, 0);
      expect(account.myGroupsCalls, 2);
    },
  );

  test('device groups remain active while no account is signed in', () async {
    final device = _FakeGroups([
      const CustomGroup(
        id: 'device',
        name: 'Device',
        isPublic: true,
        balls: [],
      ),
    ]);
    final account = _FakeGroups(const []);
    final repository = AccountAwareCustomGroupRepository(
      device: device,
      account: account,
      isAccountActive: () async => false,
      adoptGroupsFrom: (_) async => fail('must not adopt while signed out'),
    );

    expect((await repository.myGroups()).single.id, 'device');
    expect(device.myGroupsCalls, 1);
    expect(account.myGroupsCalls, 0);
  });

  test(
    'group balls travel in links as g.<uuid> and resolve from the group store',
    () {
      final ball = _groupBall('0b7c', 'Goku');
      final uri =
          ReplayLink(
            seed: 9,
            speedMultiplier: 1,
            contestants: [ball, LocalBallRepository.presets[0]],
          ).toUri(
            presetIds: {for (final b in LocalBallRepository.presets) b.id},
            appUrl: kWebAppUrl,
          );

      expect(uri.toString(), contains('balls=g.0b7c,p.preset-usa'));
      expect(ReplayLink.groupBallIds(uri), ['group:0b7c']);
      expect(
        ReplayLink.fromUri(uri, presets: LocalBallRepository.presets),
        isNull,
      );
      final parsed = ReplayLink.fromUri(
        uri,
        presets: LocalBallRepository.presets,
        packBalls: {ball.id: ball},
      )!;
      expect(parsed.contestants.first, same(ball));
    },
  );

  test(
    'the suggested color is the most common vivid color, ignoring white and transparent',
    () {
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
    },
  );

  test('group share links carry the group id', () {
    const id = '0b7c2d4e-1f2a-4b3c-8d9e-0a1b2c3d4e5f';
    final uri = ReplayLink.groupUri(id, appUrl: kWebAppUrl);
    expect(uri.toString(), '$kWebAppUrl?g=$id');
    expect(ReplayLink.sharedGroupId(uri), id);
    expect(ReplayLink.sharedGroupId(Uri.parse('$kWebAppUrl?g=nope')), isNull);
    expect(ReplayLink.sharedGroupId(Uri.parse(kWebAppUrl)), isNull);
  });

  testWidgets(
    'the category filter switches between Default, Mine and Shared and is remembered',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MatchSetupScreen(
            customGroups: _FakeGroups(
              [
                CustomGroup(
                  id: 'g1',
                  name: 'Anime',
                  isPublic: true,
                  balls: [_groupBall('a', 'Goku'), _groupBall('b', 'Luffy')],
                ),
              ],
              saved: [
                CustomGroup(
                  id: 'g9',
                  name: 'Barkada',
                  isPublic: true,
                  balls: [_groupBall('c', 'Juan'), _groupBall('d', 'Maria')],
                ),
              ],
            ),
            onStartBattle: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Default (built-in packs) first: none in this test.
      expect(find.text('No categories yet.'), findsOneWidget);
      expect(find.text('Goku'), findsNothing);

      await tester.tap(find.text('Mine'));
      await tester.pumpAndSettle();
      expect(find.text('Goku'), findsOneWidget);
      expect(find.text('Juan'), findsNothing);

      await tester.tap(find.text('Shared'));
      await tester.pumpAndSettle();
      expect(find.text('Juan'), findsOneWidget);

      // Remembered next time.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: MatchSetupScreen(
            customGroups: _FakeGroups(
              const [],
              saved: [
                CustomGroup(
                  id: 'g9',
                  name: 'Barkada',
                  isPublic: true,
                  balls: [_groupBall('c', 'Juan')],
                ),
              ],
            ),
            onStartBattle: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Juan'), findsOneWidget);
    },
  );

  testWidgets('an empty filter says how to get groups', (tester) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MatchSetupScreen(
          customGroups: _FakeGroups(const []),
          onStartBattle: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mine'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Make one in My groups'), findsOneWidget);
  });

  testWidgets(
    'My Groups lists added groups read-only, with a way to remove them',
    (tester) async {
      final repo = _FakeGroups(
        const [],
        saved: [
          CustomGroup(
            id: 'g9',
            name: 'Barkada',
            isPublic: true,
            balls: [_groupBall('c', 'Juan')],
          ),
        ],
      );
      tester.view.physicalSize = const Size(1080, 2000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: MyGroupsScreen(repository: repo)),
      );
      await tester.pumpAndSettle();
      expect(find.text('ADDED FROM OTHERS'), findsOneWidget);
      expect(
        find.text('Add'),
        findsNothing,
      ); // no adding balls to someone else's group

      await tester.tap(find.byTooltip('Group options'));
      await tester.pumpAndSettle();
      expect(find.text('Copy share link'), findsOneWidget);
      expect(find.text('Rename'), findsNothing);
      await tester.tap(find.text('Remove from my categories'));
      await tester.pumpAndSettle();
      expect(repo.unsaved, ['g9']);
    },
  );

  testWidgets('my groups show up as categories in Match Setup', (tester) async {
    MatchConfig? started;
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MatchSetupScreen(
          customGroups: _FakeGroups([
            CustomGroup(
              id: 'g1',
              name: 'Anime',
              isPublic: true,
              balls: [_groupBall('a', 'Goku'), _groupBall('b', 'Luffy')],
            ),
            const CustomGroup(
              id: 'g2',
              name: 'Empty group',
              isPublic: true,
              balls: [],
            ),
          ]),
          onStartBattle: (c) => started = c,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mine'));
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

  testWidgets(
    'tapping a ball in My Groups opens it for editing; saving without a new picture keeps it',
    (tester) async {
      final repo = _FakeGroups([
        CustomGroup(
          id: 'g1',
          name: 'Anime',
          isPublic: true,
          balls: [_groupBall('a', 'Goku')],
        ),
      ]);
      tester.view.physicalSize = const Size(1080, 2000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: MyGroupsScreen(repository: repo)),
      );
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
    },
  );

  testWidgets('the ball editor saves the gender when editing', (tester) async {
    final repo = _FakeGroups([
      CustomGroup(
        id: 'g1',
        name: 'Anime',
        isPublic: true,
        balls: [_groupBall('a', 'Goku').copyWith(gender: BallGender.male)],
      ),
    ]);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: MyGroupsScreen(repository: repo)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goku'));
    await tester.pumpAndSettle();

    final gender = find.byKey(const ValueKey('ball-gender'));
    expect(gender, findsOneWidget);
    expect(tester.widget<SegmentedButton<BallGender>>(gender).selected, {
      BallGender.male,
    });
    await tester.tap(
      find.descendant(of: gender, matching: find.text('Female')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.updates.single['gender'], BallGender.female);
  });

  testWidgets('the ball editor saves the gender when adding', (tester) async {
    final repo = _FakeGroups(const []);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BallEditorSheet(groupId: 'g1', repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final gender = find.byKey(const ValueKey('ball-gender'));
    expect(tester.widget<SegmentedButton<BallGender>>(gender).selected, {
      BallGender.none,
    });
    await tester.enterText(find.byType(TextField), 'Maria');
    await tester.tap(
      find.descendant(of: gender, matching: find.text('Female')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(repo.added.single['name'], 'Maria');
    expect(repo.added.single['gender'], BallGender.female);
  });

  group('the gender column', () {
    test('maps both ways; missing or unknown values read as none', () {
      for (final g in BallGender.values) {
        expect(
          SupabaseCustomGroupRepository.genderOf({
            'gender': SupabaseCustomGroupRepository.genderValue(g),
          }),
          g,
        );
      }
      expect(
        SupabaseCustomGroupRepository.genderValue(BallGender.female),
        'female',
      );
      expect(SupabaseCustomGroupRepository.genderOf({}), BallGender.none);
      expect(
        SupabaseCustomGroupRepository.genderOf({'gender': 'robot'}),
        BallGender.none,
      );
    });

    test('a missing column is retried once without it, then left out', () async {
      final column = OptionalColumn('gender');
      final calls = <bool>[];
      Future<String> run(bool withColumn) async {
        calls.add(withColumn);
        if (withColumn) {
          throw const PostgrestException(
            message:
                "Could not find the 'gender' column of 'group_balls' in the schema cache",
            code: 'PGRST204',
          );
        }
        return 'saved';
      }

      expect(await column.run(run), 'saved');
      expect(calls, [true, false]);
      expect(await column.run(run), 'saved');
      expect(calls, [true, false, false]); // remembered
    });

    test('a select of the missing column is retried too', () async {
      final column = OptionalColumn('gender');
      final calls = <bool>[];
      final result = await column.run((withColumn) async {
        calls.add(withColumn);
        if (withColumn) {
          throw const PostgrestException(
            message: 'column group_balls_1.gender does not exist',
            code: '42703',
          );
        }
        return 1;
      });
      expect(result, 1);
      expect(calls, [true, false]);
    });

    test('other errors are not swallowed', () async {
      final column = OptionalColumn('gender');
      var calls = 0;
      await expectLater(
        column.run<int>((_) async {
          calls++;
          throw const PostgrestException(message: 'nope', code: '42501');
        }),
        throwsA(isA<PostgrestException>()),
      );
      expect(calls, 1);
      expect(column.available, isTrue);
    });
  });

  // A new repository per test: it caches its first load, and a load made
  // under one test's fake clock never completes under the next one's.
  BallPackRepository packs() => BallPackRepository(
    baseUri: Uri.parse('http://localhost:1/packs/'),
    fetch: (_) async =>
        '{"version": 1, "groups": [{"id": "anime", "name": "Anime Pack", "style": "logo", "balls": ['
        '{"id": "a1", "name": "Naruto", "image": "anime/a1.svg", "color": "#FF8800"},'
        '{"id": "a2", "name": "Sasuke", "image": "anime/a2.svg", "color": "#222266"}]}]}',
  );

  testWidgets("groups the admin added to a main category show up inside it", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MatchSetupScreen(
          packRepository: packs(),
          customGroups: _FakeGroups(
            const [],
            extras: [
              CustomGroup(
                id: 'g7',
                name: 'More anime',
                isPublic: true,
                packId: 'anime',
                balls: [_groupBall('x', 'Goku')],
              ),
            ],
          ),
          onStartBattle: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Naruto'), findsOneWidget);
    expect(find.text('Goku'), findsOneWidget); // merged into "Anime Pack"
  });

  testWidgets(
    "in Everyone's groups the admin adds a player's group to a main category",
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final repo = _FakeGroups([
        CustomGroup(
          id: 'g1',
          name: 'Barkada',
          isPublic: true,
          ownerId: 'someone',
          balls: [_groupBall('c', 'Juan')],
        ),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: MyGroupsScreen(
            repository: repo,
            allGroups: true,
            packRepository: packs(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Group options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to main category…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anime Pack'));
      await tester.pumpAndSettle();
      expect(repo.links, {'g1': 'anime'});
    },
  );

  testWidgets(
    "Everyone's groups: a switch for others' groups, a note on your own",
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final repo = _FakeGroups([
        CustomGroup(
          id: 'g1',
          name: 'Family',
          isPublic: true,
          ownerId: 'me',
          balls: [_groupBall('a', 'Rinna')],
        ),
        CustomGroup(
          id: 'g2',
          name: 'RPG Games',
          isPublic: true,
          ownerId: 'someone',
          balls: [_groupBall('b', 'Zelda')],
        ),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: MyGroupsScreen(
            repository: repo,
            allGroups: true,
            packRepository: packs(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Yours: always in your categories'), findsOneWidget);
      expect(find.text('In my categories'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    },
  );

  testWidgets('players submit their own group for the main categories', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final repo = _FakeGroups([
      CustomGroup(
        id: 'g1',
        name: 'Barkada',
        isPublic: true,
        balls: [_groupBall('c', 'Juan')],
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(home: MyGroupsScreen(repository: repo)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Group options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit to main categories'));
    await tester.pumpAndSettle();
    expect(repo.submissions, {'g1': true});
    expect(find.textContaining('Submitted'), findsOneWidget);
  });

  testWidgets('the admin can make a group a new main category of its own', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final repo = _FakeGroups([
      CustomGroup(
        id: 'g1',
        name: 'Barkada',
        isPublic: true,
        ownerId: 'someone',
        balls: [_groupBall('c', 'Juan')],
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: MyGroupsScreen(
          repository: repo,
          allGroups: true,
          packRepository: packs(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Group options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to main category…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New category'));
    await tester.pumpAndSettle();
    expect(repo.links, {'g1': CustomGroup.ownCategory});
  });

  testWidgets('a group made its own main category shows under Default', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MatchSetupScreen(
          packRepository: packs(),
          customGroups: _FakeGroups(
            const [],
            extras: [
              CustomGroup(
                id: 'g8',
                name: 'Barkada',
                isPublic: true,
                packId: CustomGroup.ownCategory,
                balls: [_groupBall('c', 'Juan'), _groupBall('d', 'Maria')],
              ),
            ],
          ),
          onStartBattle: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownMenu<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Barkada').last);
    await tester.pumpAndSettle();
    expect(find.text('Juan'), findsOneWidget);
  });

  testWidgets(
    "Everyone's groups are A-Z and searchable by group or ball name",
    (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final repo = _FakeGroups([
        CustomGroup(
          id: 'g1',
          name: 'Zoo',
          isPublic: true,
          ownerId: 'x',
          balls: [_groupBall('a', 'Lion')],
        ),
        CustomGroup(
          id: 'g2',
          name: 'anime',
          isPublic: true,
          ownerId: 'x',
          balls: [_groupBall('b', 'Goku')],
        ),
        CustomGroup(
          id: 'g3',
          name: 'Barkada',
          isPublic: true,
          ownerId: 'x',
          balls: [_groupBall('c', 'Juan')],
        ),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: MyGroupsScreen(
            repository: repo,
            allGroups: true,
            packRepository: packs(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final ys = [
        for (final n in ['anime', 'Barkada', 'Zoo'])
          tester.getTopLeft(find.textContaining(n).first).dy,
      ];
      expect(ys, orderedEquals([...ys]..sort()));

      await tester.enterText(find.byType(TextField), 'goku');
      await tester.pumpAndSettle();
      expect(find.textContaining('anime'), findsOneWidget);
      expect(find.textContaining('Zoo'), findsNothing);
    },
  );
}
