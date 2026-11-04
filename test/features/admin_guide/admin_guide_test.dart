import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/core/offline/device_prefs.dart';
import 'package:ballwars/features/admin_guide/domain/admin_guide.dart';
import 'package:ballwars/features/admin_guide/presentation/admin_guide_screen.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/skills/presentation/skill_effects_editor.dart';
import '../../batch2/skill_editor_safety_test.dart' as editor;

void main() {
  setUp(() => OfflineStore.instance = MemoryOfflineStore());
  testWidgets('catalog covers every visual event and contextual editor topic', (
    tester,
  ) async {
    final articles = await AdminGuide.load();
    final allText = articles.map((a) => a.searchText).join(' ');
    for (final role in SkillVisualRole.values) {
      expect(
        allText,
        contains(effectRoleLabel(role).toLowerCase()),
        reason: role.name,
      );
    }
    for (var section = 0; section < 6; section++) {
      for (var appearance = 0; appearance < 7; appearance++) {
        expect(
          articles.any((a) => a.id == guideTopicForEditor(section, appearance)),
          isTrue,
        );
      }
    }
    expect(
      articles
          .firstWhere((a) => a.id == 'limitations')
          .matches('flamethrower gun tip'),
      isTrue,
    );
    expect(() => AdminGuide.decode('{"version":99}'), throwsFormatException);
  });

  for (final size in [const Size(320, 640), const Size(1200, 800)]) {
    testWidgets(
      'search spans tabs, clear restores tab, system back returns to topics at ${size.width}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(const MaterialApp(home: AdminGuideScreen()));
        await tester.pumpAndSettle();
        expect(find.text('Create your first skill'), findsOneWidget);
        await tester.tap(find.text('Parameters'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('admin-guide-search')),
          'flame thrower',
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('results across all tabs'), findsOneWidget);
        await tester.tap(find.text('Troubleshooting and current limits'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('The built-in flamethrower currently'),
          findsOneWidget,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('admin-guide-search')),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('Clear guide search'));
        await tester.pumpAndSettle();
        expect(find.textContaining('results across all tabs'), findsNothing);
        expect(
          find.text('Identity, behavior and availability'),
          findsOneWidget,
        );
        expect(await DevicePrefs.read('admin-guide-tab'), '2');
        expect(tester.takeException(), isNull);
      },
    );
  }


  testWidgets('parameter help opens the matching explanation first and keeps the draft', (tester) async {
    var saves = 0;
    await editor.library(tester, save: (_) async { saves++; });
    await editor.open(tester);
    final damage = await editor.damage(tester);
    await tester.enterText(damage, '7');
    final controller = tester.widget<TextField>(damage).controller!;
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final help = find.byKey(const ValueKey('skill-number-help-knockback'));
    await tester.scrollUntilVisible(help, 200, scrollable: find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)).first);
    await Scrollable.ensureVisible(tester.element(help), alignment: .2);
    await tester.pumpAndSettle();
    await tester.tap(help);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read full guide'));
    await tester.pumpAndSettle();
    final match = find.text('Knockback strength and Effect strength');
    expect(match.hitTestable(), findsOneWidget);
    expect(find.text('Matching explanation first'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(AdminGuideScreen), findsNothing);
    expect(find.byKey(const ValueKey('skill-settings-info')), findsOneWidget);
    expect(controller.text, '7');
    expect(saves, 0);
  });

  testWidgets(
    'editor contextual guide preserves unsaved damage without saving',
    (tester) async {
      var saves = 0;
      await editor.library(
        tester,
        save: (_) async {
          saves++;
        },
      );
      await editor.open(tester);
      final damage = await editor.damage(tester);
      await tester.enterText(damage, '7');
      await tester.tap(find.byKey(const ValueKey('skill-settings-info')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('skill-open-full-guide')));
      await tester.pumpAndSettle();
      expect(
        find.text('Damage, healing and projectile mechanics'),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(damage).controller!.text, '7');
      expect(saves, 0);
      expect(find.text('Unsaved skill changes'), findsNothing);
    },
  );
}
