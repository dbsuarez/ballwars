import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// The headline over the arena (the admin's text, "WHO WINS?" by default)
/// with a small round label under it.
class MatchStatusHeader extends StatelessWidget {
  final String headline;
  final String subtitle;
  final bool dimmed;
  final TextAlign align;

  const MatchStatusHeader({
    super.key,
    this.headline = 'WHO WINS?',
    this.subtitle = 'ROUND 1',
    this.dimmed = false,
    this.align = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    return Opacity(
      opacity: dimmed ? 0.4 : 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: align == TextAlign.center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(
            headline,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: align,
            style: AppText.ui(20, FontWeight.w800, color: c.text, letterSpacing: 0.8),
          ),
          const SizedBox(height: 2),
          Text(subtitle, textAlign: align, style: AppText.mono(11, color: c.muted, letterSpacing: 1.3)),
        ],
      ),
    );
  }
}

/// "SLOW MOTION" pill (dot + label), shown at the top of the arena.
class SlowMotionBadge extends StatelessWidget {
  const SlowMotionBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(13)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: Color(0xFFFF7A59), shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text('SLOW MOTION', style: AppText.mono(10, color: c.text, letterSpacing: 1.4)),
        ],
      ),
    );
  }
}
