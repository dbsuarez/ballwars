import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import '../../ball_management/domain/custom_ball.dart';

/// Where the web app is hosted (GitHub Pages). Links made outside a browser
/// point here; links made in the browser use the page's own address.
const String kWebAppUrl = 'https://dbsuarez.github.io/ballwars/';

/// A shareable link that replays one exact match in the web app:
/// `<app>?seed=..&speed=..&balls=..`. The replay rides in a plain query
/// string on the app's own page (no `#`, and no server-side routing needed on
/// GitHub Pages). Older `<app>#/replay?..` links are still understood.
///
/// Matches are deterministic, so the seed, the contestants (in order) and
/// their physics settings are enough to reproduce it. Ball tokens:
/// - `p.<id>`: a preset ball;
/// - `k.<pack>/<ball>`: a built-in pack ball (logo/flag included);
/// - `c.<base64 json>`: a custom ball. Uploaded images can't fit in a link,
///   so these replay with their colors and initial.
class ReplayLink {
  final int seed;
  final double speedMultiplier;
  final List<CustomBall> contestants;

  const ReplayLink({required this.seed, required this.speedMultiplier, required this.contestants});

  /// [presets] are balls every copy of the app has; they are linked by id.
  Uri toUri({required Set<String> presetIds, String? appUrl}) {
    final balls = contestants.map((b) {
      if (presetIds.contains(b.id)) return 'p.${b.id}';
      if (b.id.startsWith(_packPrefix)) return 'k.${b.id.substring(_packPrefix.length)}';
      return 'c.${_encodeCustom(b)}';
    });
    final app = Uri.parse(appUrl ?? defaultAppUrl);
    // Built by hand so the ball list keeps its readable commas.
    final query = 'seed=$seed&speed=$speedMultiplier&balls=${balls.join(',')}';
    return Uri.parse('${app.replace(query: '', fragment: '').toString().replaceAll(RegExp(r'[?#]+$'), '')}?$query');
  }

  /// The replay in [uri], or null if it isn't a valid replay link.
  /// [packBalls] maps pack ball ids (`pack:streaming/netflix`) to balls.
  static ReplayLink? fromUri(
    Uri uri, {
    required List<CustomBall> presets,
    Map<String, CustomBall> packBalls = const {},
  }) {
    final params = _params(uri);
    final seed = int.tryParse(params['seed'] ?? '');
    final speed = double.tryParse(params['speed'] ?? '1') ?? 1.0;
    final tokens = (params['balls'] ?? '').split(',').where((t) => t.isNotEmpty).toList();
    if (seed == null || tokens.length < 2) return null;

    final contestants = <CustomBall>[];
    for (var i = 0; i < tokens.length; i++) {
      final ball = _decodeBall(tokens[i], i, presets, packBalls);
      if (ball == null) return null;
      contestants.add(ball);
    }
    return ReplayLink(seed: seed, speedMultiplier: speed, contestants: contestants);
  }

  /// The running page's address on web (so local builds link to themselves).
  static String get defaultAppUrl {
    if (!kIsWeb) return kWebAppUrl;
    return Uri.base.replace(query: '', fragment: '').toString().replaceAll(RegExp(r'[?#]+$'), '');
  }

  static String _encodeCustom(CustomBall b) => base64Url
      .encode(utf8.encode(jsonEncode({
        'n': b.name,
        'p': b.primaryColor.toARGB32(),
        'g': b.glowColor.toARGB32(),
        's': b.baseSpeed,
        'm': b.mass,
      })))
      .replaceAll('=', '');

  /// Whether [uri] is a replay link that needs the built-in packs loaded.
  static bool usesPacks(Uri uri) => (_params(uri)['balls'] ?? '').split(',').any((t) => t.startsWith('k.'));

  static const String _packPrefix = 'pack:';

  static Map<String, String> _params(Uri uri) =>
      uri.fragment.startsWith('/replay') ? Uri.parse(uri.fragment).queryParameters : uri.queryParameters;

  static CustomBall? _decodeBall(
    String token,
    int index,
    List<CustomBall> presets,
    Map<String, CustomBall> packBalls,
  ) {
    if (token.startsWith('p.')) {
      final id = token.substring(2);
      return presets.where((b) => b.id == id).firstOrNull;
    }
    if (token.startsWith('k.')) return packBalls['$_packPrefix${token.substring(2)}'];
    if (!token.startsWith('c.')) return null;
    try {
      final raw = token.substring(2);
      final padded = raw.padRight((raw.length + 3) ~/ 4 * 4, '=');
      final data = jsonDecode(utf8.decode(base64Url.decode(padded))) as Map<String, dynamic>;
      return CustomBall(
        id: 'link-$index',
        name: data['n'] as String,
        primaryColor: Color(data['p'] as int),
        glowColor: Color(data['g'] as int),
        baseSpeed: (data['s'] as num).toDouble(),
        mass: (data['m'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}
