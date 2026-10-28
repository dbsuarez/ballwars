import 'dart:typed_data';
import 'package:ballwars/features/sprites/application/sprite_backup_service.dart';
import 'package:ballwars/features/sprites/domain/sprite_backup.dart';
import 'package:ballwars/features/sprites/presentation/sprite_backup_screen.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/core/theme/app_theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/core/sprites/sprite_registry.dart';
import 'sprite_backup_test.dart' show BackupRepo, atlas, a;
import 'sprite_import_screen_test.dart' show Picker, imageBytes;

Future<void> flush(WidgetTester tester) async {
  await tester.runAsync(
    () async => Future<void>.delayed(const Duration(milliseconds: 150)),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets(
    'restore reports a failure, retries it, and loads artwork under its original ID',
    (tester) async {
      final bytes = (await tester.runAsync(() => imageBytes(16)))!;
      final repo = BackupRepo()..fail.add(a);
      final service = SpriteBackupService(repo, fetch: (_) async => bytes);
      final backup = (await tester.runAsync(
        () => service.export([atlas(a, name: 'Clone')]),
      ))!;
      FilePicker.platform = Picker()..bytes = backup.encode();
      OfflineStore.instance = MemoryOfflineStore();
      await OfflineStore.instance.write(
        'https://example.test/$a/new.png',
        bytes,
      );
      addTearDown(() => SpriteRegistry.unregister('custom.$a'));
      await tester.pumpWidget(
        MaterialApp(
          home: SpriteBackupScreen(
            repository: repo,
            library: SkillLibrary.defaults,
            tuning: PowerUpConfig.defaults,
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Restore'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-sprite-backup')));
      await flush(tester);
      expect(repo.writes, isEmpty);
      Future<void> runRestore() async {
        await tester.tap(find.byKey(const ValueKey('restore-sprite-backup')));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        for (var i = 0; i < 12; i++) {
          await flush(tester);
          if (find.byType(LinearProgressIndicator).evaluate().isEmpty) break;
        }
        await tester.pumpAndSettle();
      }

      await runRestore();
      expect(find.text('0 restored, 0 skipped, 1 failed.'), findsOneWidget);
      expect(find.text('Retry selected entries'), findsOneWidget);
      repo.fail.clear();
      await runRestore();
      expect(find.text('1 restored, 0 skipped, 0 failed.'), findsOneWidget);
      expect(SpriteRegistry.has('custom.$a.sprite'), isTrue);
      expect(SpriteRegistry.collectionLabel('custom.$a.sprite'), 'Clone');
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('restore-sprite-backup')),
            )
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    'phone export prepares one portable file then saves from an explicit click',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bytes = (await tester.runAsync(() => imageBytes(16)))!;
      final repo = BackupRepo()..items = [atlas(a, name: 'Kage Bunshin')];
      Uint8List? saved;
      String? filename;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(AppPalettes.midnight),
          home: SpriteBackupScreen(
            repository: repo,
            library: SkillLibrary.defaults,
            tuning: PowerUpConfig.defaults,
            service: SpriteBackupService(repo, fetch: (_) async => bytes),
            saveFile: (b, n) async {
              saved = b;
              filename = n;
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kage Bunshin'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('prepare-sprite-backup')));
      await flush(tester);
      expect(find.byKey(const ValueKey('save-sprite-backup')), findsOneWidget);
      expect(saved, isNull);
      await tester.tap(find.byKey(const ValueKey('save-sprite-backup')));
      await tester.pumpAndSettle();
      expect(filename, endsWith('.bwsprites'));
      final decoded = await tester.runAsync(() => SpriteBackup.decode(saved!));
      expect(decoded!.entries.single.id, a);
      expect(repo.writes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'restore review defaults conflicts to Skip and cancellation never writes',
    (tester) async {
      final bytes = (await tester.runAsync(() => imageBytes(16)))!;
      final repo = BackupRepo()..items = [atlas(a, name: 'Original')];
      final service = SpriteBackupService(repo, fetch: (_) async => bytes);
      final backup = (await tester.runAsync(() => service.export(repo.items)))!;
      repo.items = [atlas(a, name: 'Newer artwork')];
      final picker = Picker()..bytes = backup.encode();
      FilePicker.platform = picker;
      await tester.pumpWidget(
        MaterialApp(
          home: SpriteBackupScreen(
            repository: repo,
            library: SkillLibrary.defaults,
            tuning: PowerUpConfig.defaults,
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Restore'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-sprite-backup')));
      await flush(tester);
      expect(find.textContaining('Conflict:'), findsOneWidget);
      final restore = find.byKey(const ValueKey('restore-sprite-backup'));
      expect(tester.widget<FilledButton>(restore).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('restore-choice-$a')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace existing artwork').last);
      await tester.pumpAndSettle();
      await tester.tap(restore);
      await tester.pumpAndSettle();
      expect(find.text('Restore sprite backup?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.writes, isEmpty);
      expect(tester.takeException(), isNull);
      picker.bytes = Uint8List.fromList([0, 1]);
      await tester.tap(find.byKey(const ValueKey('open-sprite-backup')));
      await flush(tester);
      expect(
        find.textContaining('Backup could not be opened.'),
        findsOneWidget,
      );
      expect(tester.widget<FilledButton>(restore).onPressed, isNull);
    },
  );
}
