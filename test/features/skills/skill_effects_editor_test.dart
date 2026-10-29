import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/sprites/sprite_registry.dart';
import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/skills/presentation/skill_management_screen.dart';
import 'package:ballwars/features/skills/presentation/skill_demo_dialog.dart';

void main() {
  late SkillManagementResult? saved;
  Future<void> open(WidgetTester tester, {String name = 'Pistol'}) async {
    saved = null;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      if (SpriteRegistry.has('qa.phasec.burst')) return;
      final recorder = ui.PictureRecorder();
      Canvas(
        recorder,
      ).drawCircle(const Offset(8, 8), 6, Paint()..color = Colors.blue);
      final picture = recorder.endRecording();
      final image = await picture.toImage(16, 16);
      await SpriteRegistry.registerDrawn('qa.phasec.burst', image, output: 16);
      image.dispose();
      picture.dispose();
    });
    final library = SkillLibrary.defaults.withDefinition(
      SkillLibrary.defaults
          .builtIn(PowerUpKind.pistol, PowerUpConfig.defaults)
          .copyWith(spriteTint: 0xff11ccee),
      PowerUpConfig.defaults,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppPalettes.midnight),
        home: SkillManagementScreen(
          initial: library,
          tuning: PowerUpConfig.defaults,
          onSave: (value) async => saved = value,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Search skills'),
      name,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, name));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(Tab, 'Appearance'));
    await tester.tap(find.widgetWithText(Tab, 'Appearance'));
    await tester.pumpAndSettle();
  }

  Future<void> sprite(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ListTile, 'Sprite'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('search-skill-sprites')),
      'qa.phasec',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('select-sprite-qa.phasec.burst')),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'persistent and event groups keep draft bindings and save both roles',
    (tester) async {
      await open(tester, name: 'Golden Armor');
      await tester.tap(find.text('Persistent'));
      await tester.pumpAndSettle();
      final newEffect = find.byKey(const ValueKey('new-effect-ownerStatus'));
      await tester.ensureVisible(newEffect);
      await tester.pumpAndSettle();
      await tester.tap(newEffect);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('effect-name')),
        'Guard aura',
      );
      await sprite(tester);
      await tester.tap(find.text('Use effect'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Events'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Events'));
      await tester.pumpAndSettle();
      final block = find.byKey(const ValueKey('effect-select-block-null'));
      await tester.ensureVisible(block);
      await tester.pumpAndSettle();
      await tester.tap(block);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guard aura').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-skill')));
      await tester.pumpAndSettle();
      final bindings = saved!.library
          .builtIn(PowerUpKind.goldenArmor, saved!.tuning)
          .visualBindings;
      expect(
        bindings[SkillVisualRole.ownerStatus]!.effectId,
        bindings[SkillVisualRole.block]!.effectId,
      );
      expect(saved!.library.effects.values.single.name, 'Guard aura');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'phone authors and previews an unsaved effect, saves placement and resets binding',
    (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('new-effect-casting')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('effect-name')),
        'Gold flash',
      );
      await sprite(tester);
      await tester.tap(find.widgetWithText(Tab, 'Placement'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('effect-field-size')),
        '1.5',
      );
      await tester.tap(find.byKey(const ValueKey('effect-attachment')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Caster hand').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(Row, 'Use skill tint').last,
          matching: find.byType(Switch),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Playback'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('effect-playback')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Natural length').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Preview').last);
      await tester.pumpAndSettle();
      final demo = tester.widget<SkillDemoDialog>(find.byType(SkillDemoDialog));
      final binding = demo.skill.visualBindings[SkillVisualRole.casting]!;
      expect(binding.scale, 1.5);
      expect(binding.attachment, EffectAttachment.hand);
      expect(binding.tint, 0xff11ccee);
      expect(
        demo.library.effects[binding.effectId]!.playback,
        EffectPlayback.natural,
      );
      expect(saved, isNull);
      await tester.tap(find.byTooltip('Close skill demo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use effect'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      await tester.tap(find.byKey(const ValueKey('save-skill')));
      await tester.pumpAndSettle();
      final skill = saved!.library.builtIn(PowerUpKind.pistol, saved!.tuning);
      expect(skill.visualBindings[SkillVisualRole.casting]!.scale, 1.5);
      expect(saved!.library.effects[binding.effectId]!.name, 'Gold flash');
      expect(
        saved!.library.effects[binding.effectId]!.durationSeconds,
        closeTo(4 / 60, .001),
      );
      await tester.tap(find.byTooltip('Reset Casting to default'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-skill')));
      await tester.pumpAndSettle();
      expect(
        saved!.library
            .builtIn(PowerUpKind.pistol, saved!.tuning)
            .visualBindings,
        isEmpty,
      );
      expect(saved!.library.effects[binding.effectId]!.name, 'Gold flash');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'canceling an effect draft does not modify the library and invalid data stays visible',
    (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('new-effect-casting')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use effect'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Choose a loaded sprite'), findsOneWidget);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-skill')));
      await tester.pumpAndSettle();
      expect(saved!.library.effects, isEmpty);
      expect(
        saved!.library
            .builtIn(PowerUpKind.pistol, saved!.tuning)
            .visualBindings,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'library-only effect can be saved, reused and found with clearable search',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('Effect library'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New effect'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('effect-name')),
        'Library only',
      );
      await sprite(tester);
      await tester.tap(find.text('Use effect'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use library'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-skill')));
      await tester.pumpAndSettle();
      expect(saved!.library.effects.values.single.name, 'Library only');
      expect(
        saved!.library
            .builtIn(PowerUpKind.pistol, saved!.tuning)
            .visualBindings,
        isEmpty,
      );
      final selector = find.byKey(const ValueKey('effect-select-muzzle-null'));
      await tester.ensureVisible(selector);
      await tester.pumpAndSettle();
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Library only').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-skill')));
      await tester.pumpAndSettle();
      expect(
        saved!.library
            .builtIn(PowerUpKind.pistol, saved!.tuning)
            .visualBindings[SkillVisualRole.muzzle]!
            .effectId,
        saved!.library.effects.keys.single,
      );
      await tester.ensureVisible(find.text('Effect library'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Effect library'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton &&
                    widget.tooltip == 'Remove skill bindings before deleting',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Search effects'),
        'not-exist',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Clear effect search'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Library only'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
