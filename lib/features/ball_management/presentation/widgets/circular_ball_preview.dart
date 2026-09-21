import 'package:flutter/material.dart';
import '../../domain/custom_ball.dart';

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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ball.glowColor, width: 3),
        boxShadow: [
          BoxShadow(color: ball.glowColor.withOpacity(0.7), blurRadius: size * 0.25, spreadRadius: 2),
        ],
      ),
      child: ClipOval(
        child: ball.imageBytes != null
            ? Image.memory(ball.imageBytes!, fit: BoxFit.cover)
            : Container(
                color: ball.primaryColor,
                alignment: Alignment.center,
                child: Text(
                  _initials,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: size * 0.32,
                  ),
                ),
              ),
      ),
    );
  }
}
