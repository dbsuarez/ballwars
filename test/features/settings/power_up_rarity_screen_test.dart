import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/settings/data/app_settings_repository.dart';
import 'package:ballwars/features/settings/domain/app_settings.dart';
import 'package:ballwars/features/settings/presentation/app_settings_scope.dart';
import 'package:ballwars/features/settings/presentation/power_up_rarity_screen.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth implements AdminAuth {
  _Auth(this.allowed);
  final bool allowed;
  @override
  String? get email => null;
  @override
  Future<bool> isAdmin() async => allowed;
  @override
  Future<void> signIn(String email, String password, {bool rememberMe = false}) async {}
  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('rarity assignment screen checks admin access', (tester) async {
    await tester.pumpWidget(AppSettingsScope(
      settings: ValueNotifier(AppSettings.defaults), adminAuth: _Auth(false),
      child: MaterialApp(theme: AppTheme.build(AppPalettes.midnight),
        home: const PowerUpRarityScreen(initial: PowerUpConfig.defaults)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Admin access required.'), findsOneWidget);
    expect(find.text('Save rarities for everyone'), findsNothing);
  });

  testWidgets('admin can reclassify an item and save the resulting config', (tester) async {
    PowerUpRarityResult? saved;
    await tester.pumpWidget(AppSettingsScope(
      settings: ValueNotifier(AppSettings.defaults), adminAuth: _Auth(true),
      child: MaterialApp(theme: AppTheme.build(AppPalettes.midnight),
        home: Builder(builder: (context) => TextButton(
          onPressed: () async { saved = await Navigator.of(context).push<PowerUpRarityResult>(
            MaterialPageRoute(builder: (_) => const PowerUpRarityScreen(initial: PowerUpConfig.defaults))); },
          child: const Text('Open'),
        )),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rarity-apple')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Epic').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save rarities for everyone'));
    await tester.pumpAndSettle();
    expect(saved!.tuning.rarityOf(PowerUpKind.apple), PowerUpRarity.epic);
    expect(saved!.tuning.rarityWeight(PowerUpRarity.normal), 50);
    expect(saved!.library, SkillLibrary.defaults);
  });

  testWidgets('custom skills are listed under their own tier and saved into the skill library', (tester) async {
    final kutsilyo = SkillLibrary.defaults.create('Kutsilyo', PowerUpKind.knife);
    final skills = SkillLibrary.defaults.withDefinition(kutsilyo, PowerUpConfig.defaults);
    PowerUpRarityResult? saved;
    await tester.pumpWidget(AppSettingsScope(
      settings: ValueNotifier(AppSettings.defaults), adminAuth: _Auth(true),
      child: MaterialApp(theme: AppTheme.build(AppPalettes.midnight),
        home: Builder(builder: (context) => TextButton(
          onPressed: () async { saved = await Navigator.of(context).push<PowerUpRarityResult>(
            MaterialPageRoute(builder: (_) => PowerUpRarityScreen(initial: PowerUpConfig.defaults, skills: skills))); },
          child: const Text('Open'),
        )),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final row = find.byKey(ValueKey('rarity-${kutsilyo.id}'));
    await tester.scrollUntilVisible(row, 300, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    expect(tester.widget<DropdownButton<PowerUpRarity>>(row).value, PowerUpRarity.normal);
    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Special').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.descendant(
        of: find.byKey(ValueKey('rarity-name-${kutsilyo.id}')), matching: find.byType(Text))).style?.color,
      PowerUpRarity.special.color,
    );
    await tester.tap(find.text('Save rarities for everyone'));
    await tester.pumpAndSettle();
    expect(saved!.library.custom.single.rarity, PowerUpRarity.special);
    // The built-in Knife is untouched.
    expect(saved!.tuning.rarityOf(PowerUpKind.knife), PowerUpRarity.normal);
    expect(saved!.tuning, PowerUpConfig.defaults);
  });
}
