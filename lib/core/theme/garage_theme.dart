import 'package:flutter/material.dart';
import 'app_theme.dart';

class GarageTheme {
  static const ink = Color(0xFF0B111B),
      panel = Color(0xFF152230),
      raised = Color(0xFF203345),
      border = Color(0xFF35495B),
      text = Color(0xFFF5F2E8),
      muted = Color(0xFFACBDCC),
      gold = Color(0xFFFFD078),
      cyan = Color(0xFF73E4E1);
  static const colors = BallWarsColors(
    background: ink,
    surface: panel,
    surfaceHigh: raised,
    border: border,
    text: text,
    muted: muted,
    isDark: true,
  );
  static ThemeData apply(ThemeData base) => base.copyWith(
    extensions: [colors],
    scaffoldBackgroundColor: ink,
    textTheme: base.textTheme.apply(fontFamily: 'Inter'),
    colorScheme: base.colorScheme.copyWith(
      primary: gold,
      onPrimary: ink,
      secondary: cyan,
      onSecondary: ink,
      surface: panel,
      onSurface: text,
      primaryContainer: raised,
      onPrimaryContainer: text,
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: ink,
      foregroundColor: text,
      titleTextStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 19,
        fontWeight: FontWeight.w800,
        color: text,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: ink,
        disabledBackgroundColor: raised,
        disabledForegroundColor: muted,
        shape: const TicketBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: text,
        side: const BorderSide(color: border),
        shape: const TicketBorder(),
      ),
    ),
    cardTheme: base.cardTheme.copyWith(
      color: panel,
      shape: const TicketBorder(side: BorderSide(color: border)),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      fillColor: panel,
      helperMaxLines: 3,
      errorMaxLines: 3,
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: cyan, width: 2),
      ),
    ),
    // Let each filled/tonal/outlined role choose its contrasting foreground.
    iconButtonTheme: const IconButtonThemeData(),
  );
}

/// The FigCraft ticket silhouette, scalable without a rendering dependency.
class TicketBorder extends OutlinedBorder {
  const TicketBorder({super.side = BorderSide.none, this.cut = 14});
  final double cut;
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);
  @override
  TicketBorder copyWith({BorderSide? side}) =>
      TicketBorder(side: side ?? this.side, cut: cut);
  @override
  ShapeBorder scale(double t) =>
      TicketBorder(side: side.scale(t), cut: cut * t);
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final c = cut.clamp(0.0, rect.shortestSide / 2);
    final b = (cut * 6 / 14).clamp(0.0, rect.shortestSide / 2);
    return Path()
      ..moveTo(rect.left, rect.top)
      ..lineTo(rect.right - c, rect.top)
      ..lineTo(rect.right, rect.top + c)
      ..lineTo(rect.right, rect.bottom - b)
      ..lineTo(rect.right - b, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(side.width), textDirection: textDirection);
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(
      getOuterPath(rect.deflate(side.width / 2), textDirection: textDirection),
      side.toPaint(),
    );
  }
}
