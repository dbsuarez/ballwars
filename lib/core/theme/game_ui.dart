import 'garage_theme.dart';
import 'garage_action_button.dart';
import 'ui_skin.dart';
import 'ui_skin_scope.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Shared game chrome. Does not change arena rendering or simulation settings.
class GameUi {
  static const navy = Color(0xFF080E2B);
  static const blue = Color(0xFF417AF4);
  static const cyan = Color(0xFF54DFFF);
  static const purple = Color(0xFFAE70FF);
  static const gold = Color(0xFFFFD458);
  static const orange = Color(0xFFFF8568);
  static const colors = BallWarsColors(
    background: navy,
    surface: Color(0xFF152349),
    surfaceHigh: Color(0xFF22366A),
    border: Color(0xFF4666A7),
    text: Color(0xFFF5F7FF),
    muted: Color(0xFFB8C8E9),
    isDark: true,
  );
  static ThemeData theme(BuildContext context) {
    if (UiSkinScope.of(context) == UiSkin.garage) {
      return GarageTheme.apply(Theme.of(context));
    }
    final inherited = BallWarsColors.of(context);
    final standard =
        inherited.background == AppPalettes.midnight.background &&
        inherited.text == AppPalettes.midnight.foreground;
    final chrome = standard ? colors : inherited;
    final base = standard
        ? AppTheme.build(
            const ThemePreset(
              'game-lobby',
              'Game lobby',
              navy,
              Color(0xFFF5F7FF),
            ),
          )
        : Theme.of(context);
    return base.copyWith(
      extensions: [chrome],
      colorScheme: base.colorScheme.copyWith(
        primary: gold,
        onPrimary: navy,
        secondary: cyan,
        onSecondary: navy,
        surface: chrome.surface,
        onSurface: chrome.text,
        primaryContainer: chrome.surfaceHigh,
        onPrimaryContainer: chrome.text,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: chrome.background,
        foregroundColor: chrome.text,
        titleTextStyle: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: chrome.text,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: navy,
          disabledBackgroundColor: chrome.surfaceHigh,
          disabledForegroundColor: chrome.muted,
          shape: BeveledRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: chrome.surface,
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(9),
          side: const BorderSide(color: Color(0xFF4666A7)),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: chrome.surface,
        helperMaxLines: 3,
        errorMaxLines: 3,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: chrome.border),
        ),
      ),
      iconButtonTheme: const IconButtonThemeData(),
    );
  }
}

class GameTheme extends StatelessWidget {
  const GameTheme({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      Theme(data: GameUi.theme(context), child: child);
}

/// Supplies a scoped theme to the builder as well as its descendants. Native
/// controls keep their controllers, semantics and validation behavior.
class GameWorkbench extends StatelessWidget {
  const GameWorkbench({
    super.key,
    required this.builder,
    this.animateEntrance = false,
  });
  final WidgetBuilder builder;
  final bool animateEntrance;

  @override
  Widget build(BuildContext context) => GameTheme(
    child: Builder(
      builder: (context) => GameBackdrop(
        child: Theme(
          data: Theme.of(
            context,
          ).copyWith(scaffoldBackgroundColor: Colors.transparent),
          child: animateEntrance
              ? GameEntrance(child: Builder(builder: builder))
              : Builder(builder: builder),
        ),
      ),
    ),
  );
}

/// One-shot menu entrance. Reduced motion builds the final state immediately.
class GameEntrance extends StatelessWidget {
  const GameEntrance({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduced ? 1 : 0, end: 1),
      duration: reduced ? Duration.zero : const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: reduced ? 1 : value,
        child: Transform.translate(
          offset: reduced ? Offset.zero : Offset(0, 6 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

/// A rarity frame around a real, interactive library entry.
class GameSkillFrame extends StatelessWidget {
  const GameSkillFrame({super.key, required this.child, required this.color});
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    shape: UiSkinScope.of(context) == UiSkin.garage
        ? TicketBorder(side: BorderSide(color: color.withValues(alpha: .75)))
        : BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(9),
            side: BorderSide(color: color.withValues(alpha: .75)),
          ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: .13), Colors.transparent],
        ),
      ),
      child: child,
    ),
  );
}

class GameBackdrop extends StatelessWidget {
  const GameBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              key: const ValueKey('game-backdrop-artwork'),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: c.background == GameUi.navy
                        ? const [
                            Color(0xFF183778),
                            Color(0xFF161444),
                            GameUi.navy,
                          ]
                        : [c.surfaceHigh, c.surface, c.background],
                    stops: const [0, .45, 1],
                  ),
                ),
                child: UiSkinScope.of(context) == UiSkin.garage
                    ? const CustomPaint(painter: _GarageGrid())
                    : const CustomPaint(painter: _StadiumLights()),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _StadiumLights extends CustomPainter {
  const _StadiumLights();
  @override
  void paint(Canvas canvas, Size size) {
    final area = Offset.zero & size;
    canvas.drawRect(
      area,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(.8, -.45),
          radius: 1,
          colors: [GameUi.purple.withValues(alpha: .17), Colors.transparent],
        ).createShader(area),
    );
    for (var i = 0; i < 7; i++) {
      final x = size.width * (i / 6);
      final beam = Path()
        ..moveTo(x, -20)
        ..lineTo(x - 80, size.height * .5)
        ..lineTo(x + 60, size.height * .5)
        ..close();
      canvas.drawPath(
        beam,
        Paint()
          ..color = GameUi.cyan.withValues(alpha: i.isEven ? 0.025 : 0.012),
      );
    }
    for (var i = 0; i < 32; i++) {
      final x = ((i * 73 + 17) % 997) / 997 * size.width;
      final y = ((i * 137 + 47) % 991) / 991 * size.height;
      canvas.drawCircle(
        Offset(x, y),
        i.isEven ? 1.2 : .7,
        Paint()..color = GameUi.cyan.withValues(alpha: .15),
      );
    }
    final rim = Rect.fromCenter(
      center: Offset(size.width * .5, size.height * .38),
      width: size.width * 1.4,
      height: size.width * .5,
    );
    canvas.drawArc(
      rim,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = GameUi.blue.withValues(alpha: .12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_StadiumLights oldDelegate) => false;
}

class GamePanel extends StatelessWidget {
  const GamePanel({
    super.key,
    required this.child,
    this.accent = GameUi.blue,
    this.padding = const EdgeInsets.all(12),
    this.selected = false,
  });
  final Widget child;
  final Color accent;
  final EdgeInsets padding;
  final bool selected;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180),
    curve: Curves.easeOutCubic,
    decoration: ShapeDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(BallWarsColors.of(context).surfaceHigh, accent, .15)!,
          BallWarsColors.of(context).surface,
          BallWarsColors.of(context).background,
        ],
      ),
      shape: UiSkinScope.of(context) == UiSkin.garage
          ? TicketBorder(
              side: BorderSide(
                color: selected ? GarageTheme.gold : GarageTheme.border,
                width: selected ? 2 : 1,
              ),
            )
          : BeveledRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: selected ? GameUi.gold : accent.withValues(alpha: .65),
                width: selected ? 2 : 1,
              ),
            ),
      shadows: [
        BoxShadow(
          color: (selected ? GameUi.gold : Colors.black).withValues(
            alpha: selected ? 0.16 : 0.25,
          ),
          blurRadius: selected ? 14 : 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Padding(padding: padding, child: child),
  );
}

class GameActionButton extends StatelessWidget {
  const GameActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.play_arrow_rounded,
    this.height = 54,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final double height;
  @override
  Widget build(BuildContext context) => UiSkinScope.of(context) == UiSkin.garage
      ? GarageActionButton(
          label: label,
          onPressed: onPressed,
          icon: icon,
          height: height,
        )
      : SizedBox(
          height: math.max(
            height,
            44 * MediaQuery.textScalerOf(context).scale(1),
          ),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: onPressed == null
                    ? [
                        BallWarsColors.of(context).surfaceHigh,
                        BallWarsColors.of(context).surface,
                      ]
                    : [
                        const Color(0xFFFFEEA2),
                        GameUi.gold,
                        const Color(0xFFF3A523),
                      ],
              ),
              shape: BeveledRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              shadows: onPressed == null
                  ? []
                  : [
                      BoxShadow(
                        color: GameUi.gold.withValues(alpha: .25),
                        blurRadius: 18,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size.zero,
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                foregroundColor: GameUi.navy,
                disabledForegroundColor: BallWarsColors.of(context).muted,
                shadowColor: Colors.transparent,
                shape: BeveledRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: onPressed == null
                        ? BallWarsColors.of(context).border
                        : const Color(0xFFFFF3BC),
                    width: 1.5,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 28),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
}

class GameModeTile extends StatelessWidget {
  const GameModeTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.selected = false,
  });
  final String title, subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final bool selected;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: GamePanel(
          accent: accent,
          selected: selected,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: accent, size: 25),
              const SizedBox(height: 5),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: BallWarsColors.of(context).text,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (MediaQuery.textScalerOf(context).scale(1) <= 1.15) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: BallWarsColors.of(context).muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class GameSectionHeader extends StatelessWidget {
  const GameSectionHeader({super.key, required this.title, required this.icon});
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Icon(icon, color: GameUi.cyan, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: BallWarsColors.of(context).text,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: .5,
            ),
          ),
        ),
      ],
    ),
  );
}

class GameIconButton extends StatelessWidget {
  const GameIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => IconButton.outlined(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon, size: 21),
    style: IconButton.styleFrom(
      backgroundColor: BallWarsColors.of(context).surface,
      foregroundColor: BallWarsColors.of(context).text,
      shape: BeveledRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide(color: BallWarsColors.of(context).border),
    ),
  );
}

/// A single player-dialog theme wrapper; fields and validation stay unchanged.
Future<T?> showGameDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) => showDialog<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  builder: (_) => GameTheme(child: Builder(builder: builder)),
);

class _GarageGrid extends CustomPainter {
  const _GarageGrid();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = GarageTheme.cyan.withValues(alpha: .035)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GarageGrid oldDelegate) => false;
}
