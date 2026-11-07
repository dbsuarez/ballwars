// Explicit proof: flutter test test/visual/verify_figcraft_design.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _ink = Color(0xFF0B111B),
    _text = Color(0xFFF5F2E8),
    _muted = Color(0xFFACBDCC);
const _root = 'docs/ux/figcraft';

class _Ticket extends CustomClipper<Path> {
  const _Ticket();
  @override
  Path getClip(Size s) => Path()
    ..moveTo(0, 0)
    ..lineTo(s.width - 14, 0)
    ..lineTo(s.width, 14)
    ..lineTo(s.width, s.height - 6)
    ..lineTo(s.width - 6, s.height)
    ..lineTo(0, s.height)
    ..close();
  @override
  bool shouldReclip(covariant _Ticket oldClipper) => false;
}

class _SkinButton extends StatelessWidget {
  const _SkinButton(this.skin, this.label, {this.onTap, this.focusNode});
  final ui.Image skin;
  final String label;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    child: SizedBox(
      height: 56,
      child: ClipPath(
        clipper: const _Ticket(),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            focusNode: focusNode,
            child: Stack(
              fit: StackFit.expand,
              children: [
                RawImage(
                  image: skin,
                  centerSlice: const Rect.fromLTWH(24, 24, 208, 16),
                  filterQuality: FilterQuality.none,
                ),
                Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: onTap == null ? _muted : _ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Proof extends StatelessWidget {
  const _Proof(this.images, {required this.onStart, required this.focus});
  final Map<String, ui.Image> images;
  final VoidCallback onStart;
  final FocusNode focus;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _ink,
    body: Center(
      child: SizedBox(
        width: math.min(440, MediaQuery.sizeOf(context).width),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'FLUTTER FEASIBILITY',
                style: TextStyle(color: Color(0xFF73E4E1), fontSize: 12),
              ),
              const SizedBox(height: 12),
              const Text(
                'The Battle Garage',
                style: TextStyle(
                  color: _text,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Live text over text-free nine-slice PNGs. Custom clipping; native input and semantics.',
                style: TextStyle(color: _muted, fontSize: 14),
              ),
              const SizedBox(height: 24),
              _SkinButton(
                images['normal']!,
                'START MATCH',
                onTap: onStart,
                focusNode: focus,
              ),
              const SizedBox(height: 16),
              _SkinButton(images['disabled']!, 'DISABLED'),
              const SizedBox(height: 24),
              Row(
                children: [
                  for (final (tier, item) in [
                    ('rare', 'boomerang'),
                    ('special', 'rocket'),
                  ])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: SizedBox(
                          height: 180,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              RawImage(
                                image: images[tier],
                                centerSlice: const Rect.fromLTWH(
                                  24,
                                  24,
                                  208,
                                  144,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tier.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: _muted,
                                      ),
                                    ),
                                    Expanded(
                                      child: Center(
                                        child: RawImage(
                                          image: images[item],
                                          width: 76,
                                          height: 76,
                                          fit: BoxFit.contain,
                                          filterQuality: FilterQuality.none,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      item == 'rocket'
                                          ? 'Rocket Launcher'
                                          : 'Boomerang',
                                      style: const TextStyle(
                                        color: _text,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              ClipPath(
                clipper: const _Ticket(),
                child: Container(
                  height: 56,
                  color: const Color(0xFF203345),
                  child: const Center(
                    child: Text(
                      'PURE PATH ALTERNATIVE',
                      style: TextStyle(
                        color: _text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No additional runtime packages.',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'FigCraft skins render and resize with native touch and keyboard input',
    (tester) async {
      final images = <String, ui.Image>{};
      await tester.runAsync(() async {
        await (FontLoader('DesignInter')..addFont(
              Future.value(
                ByteData.sublistView(
                  await File('$_root/fonts/Inter-Variable.ttf').readAsBytes(),
                ),
              ),
            ))
            .load();
        for (final (key, relative) in [
          ('normal', 'skins/skin-primary-normal.png'),
          ('disabled', 'skins/skin-primary-disabled.png'),
          ('rare', 'skins/skin-card-rare.png'),
          ('special', 'skins/skin-card-special.png'),
          ('rocket', 'assets/rocket.png'),
          ('boomerang', 'assets/boomerang.png'),
        ]) {
          final codec = await ui.instantiateImageCodec(
            await File('$_root/$relative').readAsBytes(),
          );
          images[key] = (await codec.getNextFrame()).image;
          codec.dispose();
        }
      });
      addTearDown(() {
        for (final image in images.values) {
          image.dispose();
        }
      });
      final normal = images['normal']!;
      expect(
        Size(normal.width.toDouble(), normal.height.toDouble()),
        const Size(256, 64),
      );
      final rgba = await tester.runAsync(
        () => normal.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      expect(
        rgba!.getUint8(255 * 4 + 3),
        0,
        reason: 'The cut corner must retain real alpha.',
      );
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var started = 0;
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final key = GlobalKey();
      for (final size in [
        const Size(320, 800),
        const Size(390, 844),
        const Size(800, 480),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              theme: ThemeData(fontFamily: 'DesignInter'),
              debugShowCheckedModeBanner: false,
              home: _Proof(images, onStart: () => started++, focus: focus),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final start = find.text('START MATCH');
        await tester.ensureVisible(start);
        await tester.tap(start);
        await tester.pumpAndSettle();
        final before = started;
        focus.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(started, before + 1);
        expect(
          tester.getSize(start).width,
          lessThan(math.min(440, size.width) - 32),
        );
        if (size.width == 390) {
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            await File(
              '$_root/previews/flutter-proof-390x844.png',
            ).writeAsBytes(png!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
      expect(started, 6);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
