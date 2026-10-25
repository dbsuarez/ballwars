import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../match_setup/domain/match_config.dart';
import '../domain/fan_line.dart';
import '../domain/power_up.dart';
import '../domain/power_up_config.dart';
import '../domain/simulation_ball.dart';
import 'power_up_sprites.dart';

/// One row per ball: name, current strength and round wins. Arsenal uses a
/// compact circular life meter so the exact number stays readable on phones.
class ScoreboardOverlay extends StatelessWidget {
  final List<SimulationBall> balls;

  /// Round wins by ball id; null for a single-round match.
  final Map<String, int>? wins;
  final Map<String, int>? eliminations;

  final MatchMode mode;
  final bool compact;
  final PowerUpConfig tuning;

  const ScoreboardOverlay({
    super.key,
    required this.balls,
    this.wins,
    this.eliminations,
    this.mode = MatchMode.threads,
    this.compact = false,
    this.tuning = PowerUpConfig.defaults,
  });

  Widget _compactCards(BuildContext context) {
    final c = BallWarsColors.of(context);
    return LayoutBuilder(builder: (context, bounds) {
      final columns = balls.length >= 5 && bounds.maxWidth >= 340 ? 3 : 2;
      final width = (bounds.maxWidth - (columns - 1) * 6) / columns;
      return Wrap(spacing: 6, runSpacing: 6, children: [
        for (final ball in balls)
          SizedBox(width: width, child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 7, height: 7, decoration: BoxDecoration(
                      shape: BoxShape.circle, color: ball.config.primaryColor)),
                  const SizedBox(width: 5),
                  Expanded(child: Text(ball.config.name, maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.ui(12, FontWeight.w700, color: c.text))),
                ]),
                const SizedBox(height: 4),
                Text(ball.isEliminated ? 'OUT' : [
                  mode == MatchMode.arsenal ? '${ball.life.round()} HP' : '${ball.lineCount} lines',
                  if (eliminations != null) '${eliminations![ball.config.id] ?? 0} KOs',
                  if (wins != null) _winsDetail(ball),
                ].join(' / '), maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: AppText.mono(11, color: c.muted)),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: ball.isEliminated ? 0 : mode == MatchMode.arsenal
                      ? (ball.life / PowerUpTuning.arenaLife).clamp(0.0, 1.0)
                      : (ball.startLines == 0 ? 0.0 : ball.lineCount / ball.startLines).clamp(0.0, 1.0),
                  color: ball.config.primaryColor, backgroundColor: c.border,
                  minHeight: 3,
                ),
                SizedBox(height: 18, child: Row(children: [
                  for (final item in _items(ball).take(3))
                    Padding(padding: const EdgeInsets.only(right: 4),
                        child: Tooltip(message: item.label, child: PowerUpIcon(item, size: 16))),
                ])),
              ]),
            ),
          )),
      ]);
    });
  }

  /// Health as hearts out of 10, rounded to the nearest half heart. Arsenal life above full (from an
  /// apple) counts past 10.
  double _hearts(SimulationBall ball) {
    if (ball.isEliminated) return 0;
    final ratio = mode == MatchMode.arsenal
        ? (ball.life / PowerUpTuning.arenaLife).clamp(
            0.0,
            PowerUpTuning.arenaMaxLife / PowerUpTuning.arenaLife,
          )
        : (ball.startLines == 0 ? 0.0 : ball.lineCount / ball.startLines).clamp(
            0.0,
            1.0,
          );
    return (ratio * 20).round() / 2;
  }

  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    if (compact) return _compactCards(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final ball in balls)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        ball.config.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.ui(
                          14,
                          FontWeight.w700,
                          color: ball.isEliminated ? c.muted : c.text,
                        ),
                      ),
                    ),
                    if (eliminations != null) ...[
                      Text(
                        '${eliminations![ball.config.id] ?? 0} KOs',
                        style: AppText.mono(12, color: c.muted),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (mode == MatchMode.arsenal) ...[
                      if (wins != null) ...[
                        Text(
                          _winsDetail(ball),
                          style: AppText.mono(11, color: c.muted),
                        ),
                        const SizedBox(width: 8),
                      ],
                      CircularLifeMeter(
                        life: ball.isEliminated ? 0 : ball.life,
                        color: ball.config.primaryColor,
                        trackColor: c.border,
                      ),
                    ] else
                      Text(
                        _detail(ball),
                        style: AppText.mono(12, color: c.muted),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                SizedBox(
                  key: ValueKey('equipment-strip-${ball.config.id}'),
                  height: 24,
                  child: Row(
                    children: [
                      for (final kind in _items(ball).take(4))
                        Expanded(
                          child: Tooltip(
                            message: kind.label,
                            child: Semantics(
                              label: kind.label,
                              child: ExcludeSemantics(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      PowerUpIcon(kind, size: 20),
                                      const SizedBox(width: 4),
                                      Text(
                                        kind.label,
                                        maxLines: 1,
                                        style: AppText.ui(
                                          11,
                                          FontWeight.w600,
                                          color: tuning.rarityOf(kind)?.color ?? c.muted,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (mode == MatchMode.allOut) ...[
                  const SizedBox(height: 8),
                  HeartsRow(
                    hearts: _hearts(ball),
                    color: ball.config.primaryColor,
                    empty: c.border,
                  ),
                ] else if (mode == MatchMode.threads) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value:
                          ball.lineCount.clamp(0, kRimSlotCount) /
                          kRimSlotCount,
                      color: ball.config.primaryColor,
                      backgroundColor: c.border,
                      minHeight: 4,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  List<PowerUpKind> _items(SimulationBall ball) => [
    ...ball.equippedWeapons,
    if (ball.speedLeft > 0) PowerUpKind.speed,
    if (ball.frozenLeft > 0) PowerUpKind.freeze,
    if (ball.ghostLeft > 0) PowerUpKind.ghost,
    if (ball.magnetPending) PowerUpKind.magnet,
    if (ball.repulsorLeft > 0) PowerUpKind.repulsor,
    if (ball.timeBubbleLeft > 0) PowerUpKind.timeBubble,
    if (ball.vampireLeft > 0) PowerUpKind.vampire,
    if (ball.mirrorCharges > 0) PowerUpKind.mirror,
    if (ball.overchargeLeft > 0) PowerUpKind.overcharge,
    if (ball.gremlinShots > 0) PowerUpKind.gremlin,
    if (ball.magneticFieldLeft > 0) PowerUpKind.magneticField,
    if (ball.goldenArmorHits > 0) PowerUpKind.goldenArmor,
  ];

  String _detail(SimulationBall ball) {
    final lines = ball.isEliminated
        ? 'out'
        : mode == MatchMode.arsenal
        ? '${ball.life.round()} life'
        : '${ball.lineCount} lines';
    final w = wins;
    if (w == null) return lines;
    final n = w[ball.config.id] ?? 0;
    return '$lines · $n ${n == 1 ? 'win' : 'wins'}';
  }

  String _winsDetail(SimulationBall ball) {
    final n = wins?[ball.config.id] ?? 0;
    return '$n ${n == 1 ? 'win' : 'wins'}';
  }
}

/// Exact Arsenal life inside a ball-like circular progress ring. Life above
/// 100 stays full and turns gold, while the center still shows the true value.
class CircularLifeMeter extends StatelessWidget {
  final double life;
  final Color color;
  final Color trackColor;
  final double size;

  const CircularLifeMeter({
    super.key,
    required this.life,
    required this.color,
    required this.trackColor,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    final value = (life / PowerUpTuning.arenaLife).clamp(0.0, 1.0);
    final meterColor = life > PowerUpTuning.arenaLife
        ? const Color(0xFFFFC83D)
        : color;
    final number = life.round();
    return Semantics(
      label: '$number life',
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: value,
              strokeWidth: 5,
              strokeCap: StrokeCap.round,
              color: meterColor,
              backgroundColor: trackColor,
            ),
            Center(
              child: Text(
                '$number',
                maxLines: 1,
                style: AppText.mono(
                  number >= 100 ? 10 : 12,
                  color: meterColor,
                ).copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 10 hearts in [color], [hearts] of them filled (halves allowed), the rest as outlines; they empty from
/// the right. Hearts past 10 (extra life from an apple) turn the first hearts gold.
class HeartsRow extends StatelessWidget {
  final double hearts;
  final Color color;
  final Color empty;

  const HeartsRow({
    super.key,
    required this.hearts,
    required this.color,
    required this.empty,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: CustomPaint(
        painter: _HeartsPainter(hearts, color, empty),
        size: Size.infinite,
      ),
    );
  }
}

class _HeartsPainter extends CustomPainter {
  final double hearts;
  final Color color;
  final Color empty;

  _HeartsPainter(this.hearts, this.color, this.empty);

  static Path _heart(Offset c, double s) => Path()
    ..moveTo(c.dx, c.dy + s * 0.85)
    ..cubicTo(
      c.dx - s * 1.1,
      c.dy + s * 0.1,
      c.dx - s * 0.75,
      c.dy - s * 0.9,
      c.dx,
      c.dy - s * 0.35,
    )
    ..cubicTo(
      c.dx + s * 0.75,
      c.dy - s * 0.9,
      c.dx + s * 1.1,
      c.dy + s * 0.1,
      c.dx,
      c.dy + s * 0.85,
    )
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final step = size.width / 10;
    final s = (size.height / 2).clamp(0.0, step * 0.45);
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = empty;
    final fill = Paint()..color = color;
    for (var i = 0; i < 10; i++) {
      final c = Offset(step * i + s + 1, size.height / 2);
      final path = _heart(c, s);
      final f = (hearts - i).clamp(0.0, 1.0);
      if (f >= 1) {
        canvas.drawPath(path, fill);
      } else {
        canvas.drawPath(path, outline);
        if (f > 0) {
          canvas.save();
          canvas.clipRect(Rect.fromLTRB(c.dx - s * 1.2, 0, c.dx, size.height));
          canvas.drawPath(path, fill);
          canvas.restore();
        }
      }
      final extra = (hearts - 10 - i).clamp(0.0, 1.0);
      if (extra > 0) {
        canvas.save();
        if (extra < 1) {
          canvas.clipRect(Rect.fromLTRB(c.dx - s * 1.2, 0, c.dx, size.height));
        }
        canvas.drawPath(path, _gold);
        canvas.restore();
      }
    }
  }

  static final Paint _gold = Paint()..color = const Color(0xFFFFC83D);

  @override
  bool shouldRepaint(_HeartsPainter old) =>
      old.hearts != hearts || old.color != color || old.empty != empty;
}
