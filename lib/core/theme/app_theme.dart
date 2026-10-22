import 'package:flutter/material.dart';

/// A two-color theme: everything else is mixed from these.
class ThemePreset {
  final String id;
  final String name;
  final Color background;
  final Color foreground;

  const ThemePreset(this.id, this.name, this.background, this.foreground);

  bool get isDark => background.computeLuminance() < 0.4;
}

/// The themes the admin can pick (app_settings.theme). Midnight is the
/// default; the rest are the palettes in docs/color-palettes, each pair in
/// both directions.
class AppPalettes {
  AppPalettes._();

  static const ThemePreset midnight = ThemePreset('midnight', 'Midnight', Color(0xFF0A0A0B), Color(0xFFF2F2F0));

  static const List<ThemePreset> all = [
    midnight,
    ThemePreset('shadow-clay', 'Shadow Grey & Sandy Clay', Color(0xFF272727), Color(0xFFD4AA7D)),
    ThemePreset('clay-shadow', 'Sandy Clay & Shadow Grey', Color(0xFFD4AA7D), Color(0xFF272727)),
    ThemePreset('twilight-blossom', 'Deep Twilight & Cherry Blossom', Color(0xFF1A1265), Color(0xFFF9A8BB)),
    ThemePreset('blossom-twilight', 'Cherry Blossom & Deep Twilight', Color(0xFFF9A8BB), Color(0xFF1A1265)),
    ThemePreset('grape-lime', 'Vintage Grape & Lime Cream', Color(0xFF433455), Color(0xFFDDEA78)),
    ThemePreset('lime-grape', 'Lime Cream & Vintage Grape', Color(0xFFDDEA78), Color(0xFF433455)),
    ThemePreset('gunmetal-icy', 'Gunmetal & Icy Blue', Color(0xFF35393C), Color(0xFFA4D8FF)),
    ThemePreset('icy-gunmetal', 'Icy Blue & Gunmetal', Color(0xFFA4D8FF), Color(0xFF35393C)),
    ThemePreset('rose-chartreuse', 'Electric Rose & Chartreuse', Color(0xFFFE00AE), Color(0xFFC1FE1A)),
    ThemePreset('chartreuse-rose', 'Chartreuse & Electric Rose', Color(0xFFC1FE1A), Color(0xFFFE00AE)),
    ThemePreset('space-raspberry', 'Deep Space Blue & Raspberry', Color(0xFF012641), Color(0xFFEE005A)),
    ThemePreset('raspberry-space', 'Raspberry & Deep Space Blue', Color(0xFFEE005A), Color(0xFF012641)),
    ThemePreset('plum-celadon', 'Chocolate Plum & Celadon', Color(0xFF553832), Color(0xFFA8D3A8)),
    ThemePreset('celadon-plum', 'Celadon & Chocolate Plum', Color(0xFFA8D3A8), Color(0xFF553832)),
  ];

  static ThemePreset byId(String? id) => all.firstWhere((p) => p.id == id, orElse: () => midnight);
}

/// The design tokens screens and painters draw with (Theme extension).
@immutable
class BallWarsColors extends ThemeExtension<BallWarsColors> {
  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color border;
  final Color text;
  final Color muted;
  final bool isDark;

  const BallWarsColors({
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.border,
    required this.text,
    required this.muted,
    required this.isDark,
  });

  factory BallWarsColors.fromPreset(ThemePreset p) {
    Color mix(double t) => Color.lerp(p.background, p.foreground, t)!;
    return BallWarsColors(
      background: p.background,
      surface: mix(0.05),
      surfaceHigh: mix(0.09),
      border: mix(0.16),
      text: p.foreground,
      muted: mix(0.6),
      isDark: p.isDark,
    );
  }

  static BallWarsColors of(BuildContext context) =>
      Theme.of(context).extension<BallWarsColors>() ?? BallWarsColors.fromPreset(AppPalettes.midnight);

  @override
  BallWarsColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceHigh,
    Color? border,
    Color? text,
    Color? muted,
    bool? isDark,
  }) =>
      BallWarsColors(
        background: background ?? this.background,
        surface: surface ?? this.surface,
        surfaceHigh: surfaceHigh ?? this.surfaceHigh,
        border: border ?? this.border,
        text: text ?? this.text,
        muted: muted ?? this.muted,
        isDark: isDark ?? this.isDark,
      );

  @override
  BallWarsColors lerp(BallWarsColors? other, double t) {
    if (other == null) return this;
    return BallWarsColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

/// Text styles of the design: Manrope for UI (a variable font, so the
/// weight is set on its `wght` axis too) and JetBrains Mono for numbers.
class AppText {
  AppText._();

  static TextStyle ui(double size, FontWeight weight, {Color? color, double? letterSpacing, double? height}) =>
      TextStyle(
        fontFamily: 'Manrope',
        fontSize: size,
        fontWeight: weight,
        fontVariations: [FontVariation('wght', weight.value.toDouble())],
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  static TextStyle mono(double size, {Color? color, double? letterSpacing}) => TextStyle(
        fontFamily: 'JetBrains Mono',
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: letterSpacing,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

class AppTheme {
  AppTheme._();

  static ThemeData build(ThemePreset preset) {
    final c = BallWarsColors.fromPreset(preset);
    final brightness = c.isDark ? Brightness.dark : Brightness.light;
    TextStyle t(double size, FontWeight w, [Color? color]) => AppText.ui(size, w, color: color ?? c.text);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Manrope',
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      extensions: [c],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: c.text,
        onPrimary: c.background,
        secondary: c.text,
        onSecondary: c.background,
        error: const Color(0xFFFF6B5B),
        onError: const Color(0xFF1A0503),
        surface: c.background,
        onSurface: c.text,
        surfaceContainerLowest: c.background,
        surfaceContainerLow: c.surface,
        surfaceContainer: c.surface,
        surfaceContainerHigh: c.surfaceHigh,
        surfaceContainerHighest: c.surfaceHigh,
        onSurfaceVariant: c.muted,
        outline: c.border,
        outlineVariant: c.border,
      ),
      textTheme: TextTheme(
        displaySmall: t(36, FontWeight.w800),
        headlineMedium: t(28, FontWeight.w800),
        headlineSmall: t(24, FontWeight.w800),
        titleLarge: t(20, FontWeight.w700),
        titleMedium: t(16, FontWeight.w700),
        titleSmall: t(14, FontWeight.w700),
        bodyLarge: t(16, FontWeight.w500),
        bodyMedium: t(14, FontWeight.w500),
        bodySmall: t(12, FontWeight.w500, c.muted),
        labelLarge: t(15, FontWeight.w700),
        labelMedium: t(13, FontWeight.w600),
        labelSmall: t(11, FontWeight.w600, c.muted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: t(18, FontWeight.w700),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.text,
          foregroundColor: c.background,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: shape,
          textStyle: t(15, FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          side: BorderSide(color: c.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: t(14, FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.text, textStyle: t(14, FontWeight.w600)),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: c.text)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        hintStyle: t(15, FontWeight.w500, c.muted),
        labelStyle: t(14, FontWeight.w600, c.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.text, width: 1.5),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStatePropertyAll(BorderSide(color: c.border)),
          backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.text : c.surface),
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.background : c.muted),
          textStyle: WidgetStatePropertyAll(t(13, FontWeight.w700)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.background : c.muted),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.text : c.surfaceHigh),
        trackOutlineColor: WidgetStatePropertyAll(c.border),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.text,
        inactiveTrackColor: c.border,
        thumbColor: c.text,
        overlayColor: c.text.withValues(alpha: 0.08),
        trackHeight: 3,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.text, linearTrackColor: c.border),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: c.border)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: t(18, FontWeight.w700),
        contentTextStyle: t(14, FontWeight.w500, c.muted),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.border,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.text,
        contentTextStyle: t(14, FontWeight.w600, c.background),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.text,
        foregroundColor: c.background,
        extendedTextStyle: t(14, FontWeight.w700),
      ),
    );
  }
}
