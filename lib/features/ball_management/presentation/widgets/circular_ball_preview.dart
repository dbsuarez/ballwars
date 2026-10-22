import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../../core/utils/ball_image_loader.dart';
import '../../domain/custom_ball.dart';

/// A ball as shown in lists and cards: logos on a white ball ringed in the
/// ball's color, photos and flags filling it, otherwise its color and
/// initials.
class CircularBallPreview extends StatelessWidget {
  final CustomBall ball;
  final double size;

  const CircularBallPreview({super.key, required this.ball, this.size = 96});

  String get _initials {
    final parts = ball.name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  bool get _isLogo => ball.imageStyle == BallImageStyle.logo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ball.primaryColor, width: (size * 0.05).clamp(1.5, 6)),
      ),
      child: ClipOval(child: _face()),
    );
  }

  Widget _face() {
    if (ball.imageBytes != null) {
      if (!_isLogo) return Image.memory(ball.imageBytes!, fit: BoxFit.cover);
      return Container(
        color: Colors.white,
        padding: EdgeInsets.all(size * 0.14),
        child: Image.memory(ball.imageBytes!, fit: BoxFit.contain),
      );
    }
    if (ball.imageUrl == null) return _placeholder();
    return FutureBuilder<ui.Image?>(
      future: BallImageLoader.load(ball),
      builder: (context, snapshot) {
        final image = snapshot.data;
        if (image == null) return _isLogo ? Container(color: Colors.white) : _placeholder();
        if (!_isLogo) return RawImage(image: image, fit: BoxFit.cover);
        return Container(
          color: Colors.white,
          padding: EdgeInsets.all(size * 0.14),
          child: RawImage(image: image, fit: BoxFit.contain),
        );
      },
    );
  }

  Widget _placeholder() => Container(
        color: Colors.white,
        alignment: Alignment.center,
        child: Text(
          _initials,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontVariations: const [FontVariation('wght', 800)],
            color: ball.primaryColor,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.32,
          ),
        ),
      );
}
