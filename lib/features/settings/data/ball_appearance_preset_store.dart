import 'dart:convert';
import '../../../core/offline/device_prefs.dart';
import '../domain/ball_appearance.dart';

/// Named drafts are device-local; Studio Save publishes the selected appearance.
class BallAppearancePreset {
  const BallAppearancePreset({
    required this.name,
    required this.appearance,
    required this.glowEnabled,
    required this.glowWidth,
  });
  final String name;
  final BallAppearance appearance;
  final bool glowEnabled;
  final double glowWidth;
  Map<String, Object?> toJson() => {
    'name': name,
    'appearance': appearance.toJson(),
    'glow': glowEnabled,
    'width': glowWidth,
  };
  static BallAppearancePreset parse(Object? raw) {
    if (raw is! Map ||
        raw['name'] is! String ||
        (raw['name'] as String).trim().isEmpty ||
        (raw['name'] as String).length > 40 ||
        raw['appearance'] is! Map ||
        raw['glow'] is! bool ||
        raw['width'] is! num ||
        !(raw['width'] as num).isFinite) {
      throw const FormatException('Invalid appearance preset');
    }
    return BallAppearancePreset(
      name: (raw['name'] as String).trim(),
      appearance: BallAppearance.fromJson(raw['appearance']),
      glowEnabled: raw['glow'] as bool,
      glowWidth: (raw['width'] as num).toDouble().clamp(1, 12),
    );
  }
}

class BallAppearancePresetStore {
  static const key = 'ball-appearance-presets-v1';
  Future<List<BallAppearancePreset>> load() async {
    final raw = await DevicePrefs.readRequired(key);
    if (raw == null) return [];
    final data = jsonDecode(raw);
    if (data is! List || data.length > 50) {
      throw const FormatException('Invalid preset library');
    }
    final result = data.map(BallAppearancePreset.parse).toList();
    if (result.map((p) => p.name.toLowerCase()).toSet().length !=
        result.length) {
      throw const FormatException('Duplicate preset names');
    }
    return result;
  }

  Future<void> save(List<BallAppearancePreset> presets) async {
    if (presets.length > 50) {
      throw StateError('Keep up to 50 appearance presets.');
    }
    // Validate before replacing durable data.
    for (final preset in presets) {
      BallAppearancePreset.parse(preset.toJson());
    }
    if (presets.map((p) => p.name.toLowerCase()).toSet().length !=
        presets.length) {
      throw StateError('Choose a unique preset name.');
    }
    await DevicePrefs.writeRequired(
      key,
      jsonEncode(presets.map((p) => p.toJson()).toList()),
    );
  }
}
