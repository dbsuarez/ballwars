import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../../arena_simulation/domain/power_up.dart';
import '../../match_setup/domain/match_config.dart';

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
/// - `g.<uuid>`: a ball from a user group (picture included, from Supabase);
/// - `c.<base64 json>`: a custom ball. Uploaded images can't fit in a link,
///   so these replay with their colors and initial.
class ReplayLink {
  final int seed;
  final double speedMultiplier;
  final bool showEffects;
  final List<CustomBall> contestants;

  /// Changes the match, so it travels in the link (`size=`, left out for
  /// medium; older links are medium).
  final BallSize ballSize;

  /// Power-up modes: the chosen power-ups (null for all). Part of the match, so it travels as a
  /// `w.<base36 bitmask>` token after the mode token; old apps reject it like `m.`.
  final Set<PowerUpKind>? powerUps;

  /// Yes or No: the question asked (cosmetic, `q=`; old apps ignore it, which is fine).
  final String? question;

  const ReplayLink({
    required this.seed,
    required this.speedMultiplier,
    required this.contestants,
    this.showEffects = true,
    this.ballSize = BallSize.medium,
    this.mode = MatchMode.threads,
    this.question,
    this.powerUps,
  });

  static const String _weaponsPrefix = 'w.';

  static int _mask(Set<PowerUpKind> kinds) => kinds.fold(0, (m, k) => m | (1 << k.index));

  /// Longest question kept (the rest is cut).
  static const int maxQuestionLength = 100;

  /// [raw] on one line, trimmed and cut to [maxQuestionLength]; null when empty.
  static String? cleanQuestion(String? raw) {
    final q = (raw ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (q.isEmpty) return null;
    return q.length > maxQuestionLength ? q.substring(0, maxQuestionLength).trim() : q;
  }

  /// Changes the match, so it travels as a leading `m.<id>` token in the ball
  /// list (none for Threads). Apps that predate modes reject the unknown
  /// `m.` prefix, so a mode link never plays back as the wrong game there.
  final MatchMode mode;

  /// [presets] are balls every copy of the app has; they are linked by id.
  Uri toUri({required Set<String> presetIds, String? appUrl}) {
    final balls = contestants.map((b) {
      if (presetIds.contains(b.id)) return 'p.${b.id}';
      if (b.id.startsWith(_packPrefix)) return 'k.${b.id.substring(_packPrefix.length)}';
      if (b.id.startsWith(_groupPrefix)) return 'g.${b.id.substring(_groupPrefix.length)}';
      return 'c.${_encodeCustom(b)}';
    });
    final chosen = powerUps;
    final tokens = [
      if (mode != MatchMode.threads) '$_modePrefix${mode.id}',
      if (mode != MatchMode.threads && chosen != null && chosen.length < PowerUpKind.values.length)
        '$_weaponsPrefix${_mask(chosen).toRadixString(36)}',
      ...balls,
    ];
    final app = Uri.parse(appUrl ?? defaultAppUrl);
    // Built by hand so the ball list keeps its readable commas.
    final size = ballSize == BallSize.medium ? '' : '&size=${ballSize.id}';
    final q = question == null ? '' : '&q=${Uri.encodeQueryComponent(question!)}';
    final query = 'seed=$seed&speed=$speedMultiplier${showEffects ? '' : '&fx=0'}$size$q&balls=${tokens.join(',')}';
    return Uri.parse('${app.replace(query: '', fragment: '').toString().replaceAll(RegExp(r'[?#]+$'), '')}?$query');
  }

  /// The replay in [uri], or null if it isn't a valid replay link.
  /// [packBalls] maps online ball ids (`pack:streaming/netflix`,
  /// `group:<uuid>`) to balls; links using them resolve only if they're here.
  ///
  /// Links come from anywhere, so everything is checked before a match is
  /// built from it: 2-4 balls, a finite speed in [minSpeed]..[maxSpeed], sane
  /// custom-ball values and a bounded size. Anything else gives null.
  static ReplayLink? fromUri(
    Uri uri, {
    required List<CustomBall> presets,
    Map<String, CustomBall> packBalls = const {},
  }) {
    if (uri.query.length + uri.fragment.length > maxLinkLength) return null;
    final params = _params(uri);
    final seed = int.tryParse(params['seed'] ?? '');
    final speed = double.tryParse(params['speed'] ?? '1') ?? 1.0;
    final tokens = (params['balls'] ?? '').split(',').where((t) => t.isNotEmpty).toList();
    var mode = MatchMode.threads;
    if (tokens.isNotEmpty && tokens.first.startsWith(_modePrefix)) {
      final parsedMode = MatchMode.byId(tokens.removeAt(0).substring(_modePrefix.length));
      if (parsedMode == null) return null;
      mode = parsedMode;
    }
    Set<PowerUpKind>? powerUps;
    if (tokens.isNotEmpty && tokens.first.startsWith(_weaponsPrefix)) {
      final mask = int.tryParse(tokens.removeAt(0).substring(_weaponsPrefix.length), radix: 36);
      final all = (1 << PowerUpKind.values.length) - 1;
      // Only with a power-up mode, never empty, no unknown kinds.
      if (mode == MatchMode.threads || mask == null || mask <= 0 || mask & ~all != 0) return null;
      powerUps = {for (final k in PowerUpKind.values) if (mask & (1 << k.index) != 0) k};
    }
    if (seed == null || tokens.length < minBalls || tokens.length > maxBalls) return null;
    if (!speed.isFinite || speed < minSpeed || speed > maxSpeed) return null;
    final ballSize = params['size'] == null ? BallSize.medium : BallSize.byId(params['size']);
    if (ballSize == null) return null;

    final contestants = <CustomBall>[];
    for (var i = 0; i < tokens.length; i++) {
      final ball = _decodeBall(tokens[i], i, presets, packBalls);
      if (ball == null) return null;
      contestants.add(ball);
    }
    return ReplayLink(
      seed: seed,
      speedMultiplier: speed,
      contestants: contestants,
      showEffects: params['fx'] != '0',
      ballSize: ballSize,
      mode: mode,
      question: cleanQuestion(params['q']),
      powerUps: powerUps,
    );
  }

  /// A short link `<app>?r=<code>` (see ShortLinkRepository).
  static Uri shortUri(String code, {String? appUrl}) =>
      Uri.parse('${Uri.parse(appUrl ?? defaultAppUrl).replace(query: '', fragment: '').toString().replaceAll(RegExp(r'[?#]+$'), '')}?r=$code');

  /// The short-link code in [uri], if it is one.
  static String? shortCode(Uri uri) {
    final code = uri.queryParameters['r'];
    return code != null && RegExp(r'^[A-Za-z0-9]{7}$').hasMatch(code) ? code : null;
  }

  /// A link that lets anyone add the group [groupId] to their categories:
  /// `<app>?g=<group uuid>`.
  static Uri groupUri(String groupId, {String? appUrl}) =>
      Uri.parse('${Uri.parse(appUrl ?? defaultAppUrl).replace(query: '', fragment: '').toString().replaceAll(RegExp(r'[?#]+$'), '')}?g=$groupId');

  /// The group id in a group share link, if [uri] is one.
  static String? sharedGroupId(Uri uri) {
    final id = uri.queryParameters['g'];
    return id != null && RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id) ? id.toLowerCase() : null;
  }

  /// The running page's address on web (so local builds link to themselves).
  static String get defaultAppUrl {
    if (!kIsWeb) return kWebAppUrl;
    return Uri.base.replace(query: '', fragment: '').toString().replaceAll(RegExp(r'[?#]+$'), '');
  }

  static String _encodeCustom(CustomBall b) => base64Url
      .encode(
        utf8.encode(
          jsonEncode({
            'n': b.name,
            'p': b.primaryColor.toARGB32(),
            'g': b.glowColor.toARGB32(),
            's': b.baseSpeed,
            'm': b.mass,
          }),
        ),
      )
      .replaceAll('=', '');

  /// The ball tokens of a replay link in [uri] (empty if it isn't one).
  static List<String> ballTokens(Uri uri) => _params(uri)['seed'] == null
      ? const []
      : (_params(uri)['balls'] ?? '').split(',').where((t) => t.isNotEmpty).toList();

  static bool isPackToken(String token) => token.startsWith('k.');

  static bool isGroupToken(String token) => token.startsWith('g.');

  /// Whether [uri] is a replay link that needs the built-in packs loaded.
  static bool usesPacks(Uri uri) => ballTokens(uri).any(isPackToken);

  /// Ids (`group:<uuid>`) of the user-group balls a link uses.
  static List<String> groupBallIds(Uri uri) => [
    for (final t in ballTokens(uri))
      if (isGroupToken(t)) '$_groupPrefix${t.substring(2)}',
  ];

  static const String _modePrefix = 'm.';
  static const String _packPrefix = 'pack:';
  static const String _groupPrefix = 'group:';

  static Map<String, String> _params(Uri uri) =>
      uri.fragment.startsWith('/replay') ? Uri.parse(uri.fragment).queryParameters : uri.queryParameters;

  static const int minBalls = 2;
  static const int maxBalls = 4;
  static const double minSpeed = 0.25;
  static const double maxSpeed = 4;

  /// Longest accepted query (four custom balls fit easily).
  static const int maxLinkLength = 4096;
  static const int maxNameLength = 40;

  static bool _within(double v, double min, double max) => v.isFinite && v >= min && v <= max;

  static CustomBall? _decodeBall(String token, int index, List<CustomBall> presets, Map<String, CustomBall> packBalls) {
    if (token.startsWith('p.')) {
      final id = token.substring(2);
      return presets.where((b) => b.id == id).firstOrNull;
    }
    if (token.startsWith('k.')) return packBalls['$_packPrefix${token.substring(2)}'];
    if (token.startsWith('g.')) return packBalls['$_groupPrefix${token.substring(2)}'];
    if (!token.startsWith('c.')) return null;
    try {
      final raw = token.substring(2);
      final padded = raw.padRight((raw.length + 3) ~/ 4 * 4, '=');
      final data = jsonDecode(utf8.decode(base64Url.decode(padded))) as Map<String, dynamic>;
      final name = (data['n'] as String).trim();
      final baseSpeed = (data['s'] as num).toDouble();
      final mass = (data['m'] as num).toDouble();
      // Within 4x either way of the defaults; anything else is not from the app.
      if (name.isEmpty || name.length > maxNameLength) return null;
      if (!_within(baseSpeed, CustomBall.defaultBaseSpeed / 4, CustomBall.defaultBaseSpeed * 4)) return null;
      if (!_within(mass, 0.25, 4)) return null;
      return CustomBall(
        id: 'link-$index',
        name: name,
        primaryColor: Color(data['p'] as int),
        glowColor: Color(data['g'] as int),
        baseSpeed: baseSpeed,
        mass: mass,
      );
    } catch (_) {
      return null;
    }
  }
}
