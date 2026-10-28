import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/sprites/sprite_atlas.dart';
import '../../../core/sprites/sprite_registry.dart';

enum SpritePreviewBackground { dark, light, checkerboard }

class SpriteComparisonPreview extends StatefulWidget {
  const SpriteComparisonPreview({
    super.key,
    required this.source,
    required this.sprite,
    this.optimized,
    this.optimizedSprite,
    required this.background,
    required this.ballColor,
    this.spriteScale = 1,
  });
  final ui.Image source;
  final SpriteDef sprite;
  final ui.Image? optimized;
  final SpriteDef? optimizedSprite;
  final SpritePreviewBackground background;
  final Color ballColor;
  final double spriteScale;
  @override
  State<SpriteComparisonPreview> createState() =>
      _SpriteComparisonPreviewState();
}

class _SpriteComparisonPreviewState extends State<SpriteComparisonPreview>
    with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  );
  bool _playing = true;
  @override
  void initState() {
    super.initState();
    if (widget.sprite.frames.length > 1) _clock.repeat();
  }

  @override
  void didUpdateWidget(covariant SpriteComparisonPreview old) {
    super.didUpdateWidget(old);
    if (_playing && widget.sprite.frames.length > 1) {
      _clock.repeat();
    } else {
      _clock.stop();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AnimatedBuilder(
        animation: _clock,
        builder: (_, _) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final optimized in [false, true])
              Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      height: 40,
                      child: Center(
                        child: Text(
                          optimized ? 'Optimized upload' : 'Original cut',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    AspectRatio(
                      aspectRatio: 1,
                      child: optimized && widget.optimized == null
                          ? const Center(
                              child: Text(
                                'Generate a comparison below.',
                                textAlign: TextAlign.center,
                              ),
                            )
                          : CustomPaint(
                              painter: _PreviewPainter(
                                optimized ? widget.optimized! : widget.source,
                                optimized
                                    ? widget.optimizedSprite!
                                    : widget.sprite,
                                (_clock.value * 3600).floor(),
                                widget.background,
                                widget.ballColor,
                                widget.spriteScale,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: _playing ? 'Pause preview' : 'Play preview',
            onPressed: widget.sprite.frames.length < 2
                ? null
                : () => setState(() {
                    _playing = !_playing;
                    _playing ? _clock.repeat() : _clock.stop();
                  }),
            icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
          ),
          IconButton(
            tooltip: 'Replay preview',
            onPressed: () {
              _clock.value = 0;
              if (_playing && widget.sprite.frames.length > 1) _clock.repeat();
            },
            icon: const Icon(Icons.replay),
          ),
        ],
      ),
    ],
  );
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(
    this.image,
    this.sprite,
    this.step,
    this.background,
    this.ballColor,
    this.spriteScale,
  );
  final ui.Image image;
  final SpriteDef sprite;
  final int step;
  final SpritePreviewBackground background;
  final Color ballColor;
  final double spriteScale;
  @override
  void paint(Canvas canvas, Size size) {
    final light = background == SpritePreviewBackground.light;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = light ? const Color(0xffeeeeee) : const Color(0xff14152e),
    );
    if (background == SpritePreviewBackground.checkerboard) {
      for (var y = 0.0; y < size.height; y += 10) {
        for (var x = 0.0; x < size.width; x += 10) {
          canvas.drawRect(
            Rect.fromLTWH(x, y, 10, 10),
            Paint()
              ..color = ((x ~/ 10 + y ~/ 10).isEven
                  ? const Color(0xff777777)
                  : const Color(0xffbbbbbb)),
          );
        }
      }
    }
    final center = size.center(Offset.zero), side = size.shortestSide;
    canvas.drawCircle(
      center,
      side * .46,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = (light ? Colors.black : Colors.white),
    );
    canvas.drawCircle(center, side * .24, Paint()..color = ballColor);
    final i = (step ~/ sprite.stepsPerFrame) % sprite.frames.length,
        source = sprite.frames[i];
    final original = sprite.sourceSizes?[i] ?? source.size;
    final target = SpriteRegistry.placeRect(
      center,
      side * .55 * spriteScale,
      side * .55 * spriteScale,
      sprite.anchor,
    );
    final fitted = applyBoxFit(
      sprite.fit == SpriteFit.fill ? BoxFit.fill : BoxFit.contain,
      original,
      target.size,
    );
    final box = Alignment.center.inscribe(fitted.destination, target),
        offset = sprite.sourceOffsets?[i] ?? Offset.zero;
    final scale = box.width / original.width;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawImageRect(
      image,
      source,
      Rect.fromLTWH(
        box.left + offset.dx * scale,
        box.top + offset.dy * scale,
        source.width * scale,
        source.height * scale,
      ),
      Paint()..filterQuality = FilterQuality.none,
    );
    canvas.restore();
    canvas.drawCircle(
      center,
      2,
      Paint()..color = light ? Colors.black : Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter old) => true;
}
