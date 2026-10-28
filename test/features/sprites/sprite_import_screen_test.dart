import 'dart:io';
import 'dart:ui' as ui;
import 'package:ballwars/core/sprites/sprite_atlas.dart';
import 'package:ballwars/core/sprites/sprite_registry.dart';
import 'package:ballwars/core/sprites/sprite_import.dart';
import 'package:ballwars/features/sprites/presentation/sprite_editor_card.dart';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/features/sprites/data/sprite_atlas_repository.dart';
import 'package:ballwars/features/sprites/presentation/sprite_import_screen.dart';
import 'package:ballwars/features/sprites/presentation/sprite_comparison_preview.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class Picker extends FilePicker {
  late Uint8List bytes;
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => FilePickerResult([
    PlatformFile(name: 'shadow.png', size: bytes.length, bytes: bytes),
  ]);
}

class Repo implements SpriteAtlasRepository {
  SpriteAtlas? saved;
  Uint8List? bytes;
  bool fail = false;
  String? savedId;
  DateTime? expectedVersion;
  @override
  Future<CustomAtlas> save({
    String? id,
    DateTime? expectedUpdatedAt,
    bool restoreMissing = false,
    required String name,
    required Uint8List sheet,
    required String contentType,
    required SpriteAtlas atlas,
  }) async {
    if (fail) throw StateError('server unavailable');
    saved = atlas;
    savedId = id;
    expectedVersion = expectedUpdatedAt;
    bytes = sheet;
    return CustomAtlas(
      id: 'a',
      name: name,
      sheetUrl: 'https://example.test/a',
      sheetPath: 'a/a.png',
      atlas: atlas,
      updatedAt: DateTime.utc(2026),
    );
  }

  @override
  Future<List<CustomAtlas>> list() async => [];
  @override
  Future<void> delete(String id) async {}
}

Future<Uint8List> imageBytes(int size) async {
  final r = ui.PictureRecorder();
  final c = Canvas(r);
  c.drawCircle(
    Offset(size / 2, size / 2),
    size / 3,
    Paint()..color = Colors.red,
  );
  final p = r.endRecording();
  final image = await p.toImage(size, size);
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.png,
  ))!.buffer.asUint8List();
  image.dispose();
  p.dispose();
  return bytes;
}

Future<void> pick(WidgetTester tester, Picker picker) async {
  await tester.tap(find.byKey(const ValueKey('pick-sprite-sheet')));
  await tester.runAsync(
    () async => Future<void>.delayed(const Duration(milliseconds: 150)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> revealImport(
  WidgetTester tester,
  String page,
  Finder target,
) async {
  final list = find.byKey(ValueKey('sprite-import-$page'));
  for (var i = 0; i < 24; i++) {
    if (target.hitTestable().evaluate().isNotEmpty) return;
    await tester.drag(list, const Offset(0, -140));
    await tester.pumpAndSettle();
  }
  fail('Could not reveal $target on $page');
}

void main() {
  testWidgets(
    'blank animation frames require explicit inclusion or exclusion',
    (tester) async {
      final bytes = await tester.runAsync(() async {
        final r = ui.PictureRecorder();
        Canvas(
          r,
        ).drawCircle(const Offset(4, 4), 2, Paint()..color = Colors.green);
        final p = r.endRecording(), image = await p.toImage(16, 8);
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
        image.dispose();
        p.dispose();
        return bytes;
      });
      final picker = Picker()..bytes = bytes!;
      FilePicker.platform = picker;
      await tester.pumpWidget(
        MaterialApp(home: SpriteImportScreen(repository: Repo())),
      );
      await pick(tester, picker);
      await tester.tap(find.widgetWithText(Tab, 'Slices'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Increase Columns'));
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('save-sprite-upload'));
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await tester.tap(find.widgetWithText(Tab, 'Sprites'));
      await tester.pumpAndSettle();
      final allow = find.byKey(const ValueKey('allow-blank-sprite'));
      for (var i = 0; i < 12 && allow.hitTestable().evaluate().isEmpty; i++) {
        await tester.drag(
          find.byKey(const ValueKey('sprite-import-sprites')),
          const Offset(0, -180),
        );
        await tester.pumpAndSettle();
      }
      await tester.tap(allow);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      await tester.tap(allow);
      await tester.pumpAndSettle();
      await revealImport(tester, 'sprites', find.text('Exclude blank frames'));
      await tester.tap(find.text('Exclude blank frames'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      expect(
        tester
            .widget<SpriteEditorCard>(find.byType(SpriteEditorCard))
            .edit
            .excluded,
        {1},
      );
    },
  );
  testWidgets(
    'optimized comparison uses selected background and ball color without losing edits',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      if (const bool.fromEnvironment('SPRITE_IMPORT_PREVIEW')) {
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
        await (FontLoader('Manrope')
              ..addFont(rootBundle.load('assets/fonts/Manrope-Variable.ttf')))
            .load();
      }
      final picker = Picker();
      FilePicker.platform = picker;
      picker.bytes = (await tester.runAsync(() => imageBytes(32)))!;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(AppPalettes.midnight),
          home: SpriteImportScreen(repository: Repo()),
        ),
      );
      await pick(tester, picker);
      await tester.ensureVisible(find.widgetWithText(Tab, 'Preview'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Preview'));
      await tester.pumpAndSettle();
      await revealImport(
        tester,
        'preview',
        find.byKey(const ValueKey('generate-sprite-comparison')),
      );
      await tester.tap(
        find.byKey(const ValueKey('generate-sprite-comparison')),
      );
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 80)),
        );
        await tester.pump();
        if (find.text('Generating...').evaluate().isEmpty) break;
      }
      await tester.pumpAndSettle();
      expect(find.text('Optimized upload'), findsOneWidget);
      expect(find.text('Generate a comparison below.'), findsNothing);
      await tester.drag(
        find.byKey(const ValueKey('sprite-import-preview')),
        const Offset(0, 600),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sprite-preview-background')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('light').last);
      await tester.pumpAndSettle();
      if (const bool.fromEnvironment('SPRITE_IMPORT_PREVIEW')) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byType(RepaintBoundary).first,
          );
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            'build/sprite-comparison-phone.png',
          ).writeAsBytesSync(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'editing an existing atlas preserves encoded pixels and IDs while changing its readable name',
    (tester) async {
      final bytes = (await tester.runAsync(() => imageBytes(16)))!;
      final old = CustomAtlas(
        id: 'existing',
        name: 'Existing art',
        sheetUrl: 'https://example.test/existing.png',
        sheetPath: 'existing/a.png',
        atlas: SpriteImport.grid(sheet: 'old.png', width: 16, height: 16),
        updatedAt: DateTime.utc(2026),
      );
      OfflineStore.instance = MemoryOfflineStore();
      await OfflineStore.instance.write(old.sheetUrl, bytes);
      final repo = Repo();
      await tester.pumpWidget(
        MaterialApp(
          home: SpriteImportScreen(
            repository: repo,
            existing: old,
            editExisting: true,
          ),
        ),
      );
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 80)),
        );
        await tester.pump();
        if (find.text('Existing art - 16 x 16').evaluate().isNotEmpty) break;
      }
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(Tab, 'Preview'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Preview'));
      await tester.pumpAndSettle();
      final scaleControl = find.byKey(const ValueKey('sprite-preview-scale'));
      await tester.ensureVisible(scaleControl);
      tester.widget<Slider>(scaleControl).onChanged!(2);
      await tester.pump();
      expect(
        tester
            .widget<SpriteComparisonPreview>(
              find.byType(SpriteComparisonPreview),
            )
            .spriteScale,
        2,
      );
      await tester.ensureVisible(find.widgetWithText(Tab, 'Sprites'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Sprites'));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('sprite-name-sprite'));
      await tester.ensureVisible(field);
      await tester.enterText(field, 'Clone Pop');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('save-sprite-upload')));
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      expect(repo.savedId, old.id);
      expect(repo.saved!.sprites.values.single.displayScale, 2);
      expect(repo.saved!.sprites.keys, ['sprite']);
      expect(repo.saved!.sprites['sprite']!.label, 'Clone Pop');
      expect(repo.bytes, bytes);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'per-sprite edits survive tab changes and save with custom name, timing and anchor',
    (tester) async {
      final picker = Picker();
      FilePicker.platform = picker;
      picker.bytes = (await tester.runAsync(() => imageBytes(32)))!;
      final repo = Repo();
      await tester.pumpWidget(
        MaterialApp(home: SpriteImportScreen(repository: repo)),
      );
      await pick(tester, picker);
      await tester.tap(find.widgetWithText(Tab, 'Sprites'));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('sprite-name-sprite'));
      await tester.ensureVisible(field);
      await tester.enterText(field, 'kage-bunshin');
      await tester.pump();
      final card = find.byType(SpriteEditorCard);
      final stateWidget = tester.widget<SpriteEditorCard>(card);
      stateWidget.edit.stepsPerFrame = 12;
      stateWidget.edit.anchor = const Offset(0, 1);
      stateWidget.onChanged();
      await tester.pump();
      await tester.tap(find.widgetWithText(Tab, 'Sheet'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-sprite-upload')));
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Upload'));
      await tester.pumpAndSettle();
      final s = repo.saved!.sprites['kage-bunshin']!;
      expect(s.stepsPerFrame, 12);
      expect(s.anchor, const Offset(0, 1));
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'smooth resizing is baked into optimized artwork while pixel art keeps sharp samples',
    () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        final r = ui.PictureRecorder(), p = Paint()..isAntiAlias = false;
        final canvas = Canvas(r);
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 257, 257),
          p..color = Colors.black,
        );
        canvas.drawRect(
          const Rect.fromLTWH(129, 0, 128, 257),
          p..color = Colors.white,
        );
        final pic = r.endRecording(), sheet = await pic.toImage(257, 257);
        final atlas = SpriteImport.grid(
          sheet: 'edge.png',
          width: 257,
          height: 257,
        );
        final pixel = await SpriteRegistry.normalizeUpload(
          atlas,
          sheet,
          frameSize: 128,
        );
        final smooth = await SpriteRegistry.normalizeUpload(
          atlas,
          sheet,
          frameSize: 128,
          filterQuality: FilterQuality.medium,
        );
        expect(pixel.bytes, isNot(orderedEquals(smooth.bytes)));
        sheet.dispose();
        pic.dispose();
      });
    },
  );
  testWidgets(
    'removal confirmation names missing sprites and affected skills; cancel preserves old upload',
    (tester) async {
      final picker = Picker();
      FilePicker.platform = picker;
      picker.bytes = (await tester.runAsync(() => imageBytes(32)))!;
      final old = CustomAtlas(
        id: 'old',
        name: 'Weapons',
        sheetUrl: 'https://example.test/old',
        sheetPath: 'old/old.png',
        atlas: SpriteImport.grid(
          sheet: 'old.png',
          width: 64,
          height: 64,
          columns: 2,
          animation: false,
          spriteName: 'weapon',
        ),
        updatedAt: DateTime.utc(2026),
      );
      final repo = Repo();
      await tester.pumpWidget(
        MaterialApp(
          home: SpriteImportScreen(
            repository: repo,
            existing: old,
            usage: const {
              'weapon-2': ['Boom-merang'],
            },
          ),
        ),
      );
      await pick(tester, picker);
      await tester.tap(find.byKey(const ValueKey('save-sprite-upload')));
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.textContaining('Removed sprites: weapon-1, weapon-2'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Affected skills: Boom-merang'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.saved, isNull);
    },
  );
  testWidgets(
    'replacement keeps atlas and sprite IDs and sends the expected revision',
    (tester) async {
      final picker = Picker();
      FilePicker.platform = picker;
      picker.bytes = (await tester.runAsync(() => imageBytes(32)))!;
      final original = CustomAtlas(
        id: 'existing-id',
        name: 'Shadow clone icon',
        sheetUrl: 'https://example.test/old.png',
        sheetPath: 'existing/old.png',
        atlas: SpriteImport.grid(
          sheet: 'old.png',
          width: 32,
          height: 32,
          spriteName: 'kage-bunshin',
        ),
        updatedAt: DateTime.utc(2026, 10, 28),
      );
      final repo = Repo();
      await tester.pumpWidget(
        MaterialApp(
          home: SpriteImportScreen(repository: repo, existing: original),
        ),
      );
      await pick(tester, picker);
      await tester.tap(find.byKey(const ValueKey('save-sprite-upload')));
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Replace Shadow clone icon?'), findsOneWidget);
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      expect(repo.savedId, original.id);
      expect(repo.expectedVersion, original.updatedAt);
      expect(repo.saved!.sprites.keys, ['kage-bunshin']);
    },
  );
  testWidgets(
    'single high-resolution icon is normalized before upload; mobile tabs preserve edits',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final picker = Picker();
      if (const bool.fromEnvironment('SPRITE_IMPORT_PREVIEW')) {
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
        await (FontLoader('Manrope')
              ..addFont(rootBundle.load('assets/fonts/Manrope-Variable.ttf')))
            .load();
      }
      FilePicker.platform = picker;
      picker.bytes = (await tester.runAsync(() => imageBytes(1024)))!;
      final repo = Repo();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(AppPalettes.midnight),
          home: RepaintBoundary(
            key: const ValueKey('screen'),
            child: SpriteImportScreen(repository: repo),
          ),
        ),
      );
      await pick(tester, picker);
      expect(find.text('shadow.png - 1024 x 1024'), findsOneWidget);
      await tester.tap(find.text('Slices'));
      await tester.pumpAndSettle();
      expect(find.text('Columns'), findsOneWidget);
      await tester.tap(find.text('Sheet'));
      await tester.pumpAndSettle();
      expect(find.text('shadow.png - 1024 x 1024'), findsOneWidget);
      if (const bool.fromEnvironment('SPRITE_IMPORT_PREVIEW')) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('screen')),
          );
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            'build/sprite-import-phone.png',
          ).writeAsBytesSync(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.byKey(const ValueKey('save-sprite-upload')));
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Upload optimized artwork?'), findsOneWidget);
      await tester.tap(find.text('Upload'));
      await tester.pumpAndSettle();
      expect(repo.saved!.sheetSize, const Size(128, 128));
      expect(
        repo.saved!.sprites['sprite']!.frames.single,
        const Rect.fromLTWH(0, 0, 128, 128),
      );
      expect(repo.bytes, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'failed save is visible and preserves edits; wide screen stays 440 px',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final picker = Picker();
      FilePicker.platform = picker;
      picker.bytes = (await tester.runAsync(() => imageBytes(32)))!;
      final repo = Repo()..fail = true;
      await tester.pumpWidget(
        MaterialApp(home: SpriteImportScreen(repository: repo)),
      );
      expect(tester.getSize(find.byType(Scaffold)).width, 440);
      await pick(tester, picker);
      await tester.tap(find.byKey(const ValueKey('save-sprite-upload')));
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Upload'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Upload failed. Your edits are kept.'),
        findsOneWidget,
      );
      expect(find.text('shadow.png - 32 x 32'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test('resizing keeps alpha and trimmed positioning', () async {
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      final bytes = await imageBytes(1024);
      final image = await validateSpriteSheet(bytes, 'image/png', source: true);
      final result = await SpriteRegistry.normalizeUpload(
        SpriteImport.grid(sheet: 'big.png', width: 1024, height: 1024),
        image,
        frameSize: 128,
      );
      final optimized = await validateSpriteSheet(result.bytes, 'image/png');
      final rgba = (await optimized.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      expect(optimized.width, 128);
      expect(rgba.getUint8(3), 0);
      expect(rgba.getUint8((64 * 128 + 64) * 4 + 3), 255);
      optimized.dispose();
      image.dispose();
    });
  });
}
