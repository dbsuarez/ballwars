import 'dart:convert';
import 'replay_assets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../../arena_simulation/domain/power_up.dart';
import '../../arena_simulation/domain/power_up_config.dart';
import '../../match_setup/domain/match_config.dart';
import '../../settings/domain/app_settings.dart';
import '../../skills/domain/skill_library.dart';

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
  final int simulationRevision;
  final int seed;
  final double speedMultiplier;
  final bool automaticSpeedUp;
  final bool showEffects;
  final EffectRenderMode? effectRenderMode;
  final double ballGlowWidth;
  final Color bloodColor;
  final bool randomizedHairstyles;
  final List<CustomBall> contestants;

  /// Changes the match, so it travels in the link (`size=`, left out for
  /// medium; older links are medium).
  final BallSize ballSize;

  /// Power-up modes: the chosen power-ups (null for all). Part of the match, so it travels as a
  /// `w.<base36 bitmask>` token after the mode token; old apps reject it like `m.`.
  final Set<PowerUpKind>? powerUps;

  /// Power-up modes: the custom skills (ids) that could spawn; null for all. `cs=` (comma list).
  final Set<String>? customSkills;

  /// Unstuck nudges (steps) the match had; part of the match. `nudge=` (comma list).
  final List<int> nudgeSteps;

  /// Highest step `nudge=` and `end=` accept: one hour of game time at 60 steps per second.
  static const int maxLinkStep = 216000;

  /// How many [PowerUpKind]s existed before links carried `kc=` (the count before Shadow Clone). A
  /// power-up link without `kc` was made then, so only the first [legacyKindCount] kinds can spawn.
  static const int legacyKindCount = 48;

  /// The smallest `kc` an app can write (the count when `kc` was introduced).
  static const int firstLinkKindCount = 49;

  /// End battle: the step at which the player asked to end an endless (non-Mayhem) battle after the
  /// next knockout; part of the match. `end=`, only with `endless=1`.
  final int? endStep;

  /// Power-up modes: the power-up numbers the match was played with. Part of the match, so the changed
  /// values travel as `t=` ([PowerUpConfig.encode]); old links without it use the defaults.
  final PowerUpConfig tuning;

  /// Whether this match allows two equipped weapons (`dw=1`).
  final bool dualWield;
  final bool endlessBattle;
  final bool mayhem;
  final int mayhemSeconds;
  final bool shrinkingArena;
  final double minimumArenaScale;
  final ArenaDecoration arenaDecoration;
  final SkillLibrary skillLibrary;
  final Map<String, String> artworkRevisions;
  final Map<String, Object> artworkFrames;

  /// Yes or No: the question asked (cosmetic, `q=`; old apps ignore it, which is fine).
  final String? question;

  /// The ball look the match was played with (Pictures or Faces). Cosmetic: it doesn't change the match,
  /// so links without it (older ones) are still valid and use the viewer's own setting. `look=`.
  final BallLook? look;

  const ReplayLink({
    this.simulationRevision = 3,
    required this.seed,
    required this.speedMultiplier,
    this.automaticSpeedUp = true,
    required this.contestants,
    this.showEffects = true,
    this.effectRenderMode,
    this.ballGlowWidth = 4,
    this.bloodColor = const Color(0xFFD9152B),
    this.randomizedHairstyles = false,
    this.ballSize = BallSize.medium,
    this.mode = MatchMode.threads,
    this.question,
    this.look,
    this.powerUps,
    this.customSkills,
    this.nudgeSteps = const [],
    this.endStep,
    this.tuning = PowerUpConfig.defaults,
    this.dualWield = false,
    this.endlessBattle = false,
    this.mayhem = false,
    this.mayhemSeconds = 120,
    this.shrinkingArena = false,
    this.minimumArenaScale = 0.60,
    this.arenaDecoration = ArenaDecoration.defaultArena,
    this.skillLibrary = SkillLibrary.defaults,
    this.artworkRevisions = const {},
    this.artworkFrames = const {},
  });

  static const String _weaponsPrefix = 'w.';

  /// The `w.` bitmask of [kinds] (bit = [PowerUpKind.index]). BigInt, because on the web an int
  /// shift past bit 31 loses bits.
  static BigInt _mask(Set<PowerUpKind> kinds) =>
      kinds.fold(BigInt.zero, (m, k) => m | (BigInt.one << k.index));

  /// Longest question kept (the rest is cut).
  static const int maxQuestionLength = 100;

  /// [raw] on one line, trimmed and cut to [maxQuestionLength]; null when empty.
  static String? cleanQuestion(String? raw) {
    final q = (raw ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (q.isEmpty) return null;
    return q.length > maxQuestionLength
        ? q.substring(0, maxQuestionLength).trim()
        : q;
  }

  /// Changes the match, so it travels as a leading `m.<id>` token in the ball
  /// list (none for Threads). Apps that predate modes reject the unknown
  /// `m.` prefix, so a mode link never plays back as the wrong game there.
  final MatchMode mode;

  /// [presets] are balls every copy of the app has; they are linked by id.
  Uri toUri({required Set<String> presetIds, String? appUrl}) {
    final assetSnapshot = ReplayAssets.encode(
      skillLibrary,
      artworkRevisions,
      embedded: artworkFrames,
    );

    final balls = contestants.map((b) {
      if (presetIds.contains(b.id)) return 'p.${b.id}';
      if (b.id.startsWith(_packPrefix)) {
        return 'k.${b.id.substring(_packPrefix.length)}';
      }
      if (b.id.startsWith(_groupPrefix)) {
        return 'g.${b.id.substring(_groupPrefix.length)}';
      }
      return 'c.${_encodeCustom(b)}';
    });
    final chosen = powerUps;
    final tokens = [
      if (simulationRevision >= 2) 'v.$simulationRevision',
      if (assetSnapshot != null) 'a.1',
      if (mode != MatchMode.threads) '$_modePrefix${mode.id}',
      if (mode != MatchMode.threads &&
          chosen != null &&
          chosen.length < PowerUpKind.values.length)
        '$_weaponsPrefix${_mask(chosen).toRadixString(36)}',
      ...balls,
    ];
    final app = Uri.parse(appUrl ?? defaultAppUrl);
    // Built by hand so the ball list keeps its readable commas.
    final size = ballSize == BallSize.medium ? '' : '&size=${ballSize.id}';
    final q = question == null
        ? ''
        : '&q=${Uri.encodeQueryComponent(question!)}';
    final encoded = mode == MatchMode.threads ? null : tuning.encode();
    final t = encoded == null ? '' : '&t=$encoded';
    // Pins the kind pool: kinds added after this link was made never spawn when it plays back.
    final kc = mode == MatchMode.threads
        ? ''
        : '&kc=${PowerUpKind.values.length}';
    final dw = mode != MatchMode.threads && dualWield ? '&dw=1' : '';
    final endless = mode == MatchMode.arsenal && endlessBattle
        ? '&endless=1'
        : '';
    final mayhemToken = mode == MatchMode.arsenal && mayhem
        ? '&mayhem=1&duration=$mayhemSeconds'
        : '';
    final shrinking = shrinkingArena ? '&shrink=1' : '';
    final minimumArena = shrinkingArena && minimumArenaScale != 0.60
        ? '&minarena=${minimumArenaScale.toStringAsFixed(2)}'
        : '';
    final automaticSpeed = automaticSpeedUp ? '' : '&autospeed=0';
    final arena = arenaDecoration == ArenaDecoration.defaultArena
        ? ''
        : '&arena=${arenaDecoration.name}';
    final assets = assetSnapshot == null ? '' : '&assets=$assetSnapshot';
    final skillSnapshot = skillLibrary.encodeReplay();
    final skills = skillSnapshot == null ? '' : '&skills=$skillSnapshot';
    final glow = ballGlowWidth == 4
        ? ''
        : '&glow=${ballGlowWidth.toStringAsFixed(1)}';
    final blood = bloodColor.toARGB32() == 0xFFD9152B
        ? ''
        : '&blood=${bloodColor.toARGB32().toRadixString(16)}';
    final hair = randomizedHairstyles ? '&hair=1' : '';
    final lookToken = look == null ? '' : '&look=${look!.name}';
    final chosenCustom = customSkills;
    final nudgeToken = nudgeSteps.isEmpty
        ? ''
        : '&nudge=${nudgeSteps.join(',')}';
    final endToken =
        endStep != null && mode == MatchMode.arsenal && endlessBattle && !mayhem
        ? '&end=$endStep'
        : '';
    final customToken = mode == MatchMode.threads || chosenCustom == null
        ? ''
        : '&cs=${(chosenCustom.toList()..sort()).join(',')}';
    final effectVisuals = effectRenderMode == null
        ? ''
        : '&effectvisuals=${effectRenderMode!.name}';
    final query =
        'seed=$seed&speed=$speedMultiplier${showEffects ? '' : '&fx=0'}$size$q$t$kc$dw$endless$mayhemToken$shrinking$minimumArena$automaticSpeed$arena$skills$glow$blood$hair$lookToken$customToken$nudgeToken$endToken&balls=${tokens.join(',')}';
    return Uri.parse(
      '${app.replace(query: '', fragment: '').toString().replaceAll(RegExp(r'[?#]+$'), '')}?$query$effectVisuals$assets',
    );
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
    final tokens = (params['balls'] ?? '')
        .split(',')
        .where((t) => t.isNotEmpty)
        .toList();
    var mode = MatchMode.threads;
    var simulationRevision = 1;
    if (tokens.isNotEmpty && tokens.first.startsWith('v.')) {
      final marker = tokens.removeAt(0);
      if (marker != 'v.2' && marker != 'v.3') return null;
      simulationRevision = marker == 'v.3' ? 3 : 2;
    }
    final hasArtworkMarker = tokens.isNotEmpty && tokens.first == 'a.1';
    if (hasArtworkMarker) tokens.removeAt(0);
    if (hasArtworkMarker != params.containsKey('assets')) return null;
    if (tokens.isNotEmpty && tokens.first.startsWith(_modePrefix)) {
      final parsedMode = MatchMode.byId(
        tokens.removeAt(0).substring(_modePrefix.length),
      );
      if (parsedMode == null) return null;
      mode = parsedMode;
    }
    // The kinds that existed when the link was made (`kc`, strict); before `kc` there were
    // [legacyKindCount]. Later kinds are left out of the pool so the match replays as it was played.
    final kcText = params['kc'];
    final kindCount = kcText == null ? legacyKindCount : int.tryParse(kcText);
    if (kcText != null &&
        (mode == MatchMode.threads ||
            kindCount == null ||
            kindCount < firstLinkKindCount ||
            kindCount > PowerUpKind.values.length ||
            '$kindCount' != kcText)) {
      return null;
    }
    Set<PowerUpKind>? powerUps;
    if (tokens.isNotEmpty && tokens.first.startsWith(_weaponsPrefix)) {
      final text = tokens.removeAt(0).substring(_weaponsPrefix.length);
      final mask = RegExp(r'^[0-9a-zA-Z]+$').hasMatch(text)
          ? BigInt.tryParse(text, radix: 36)
          : null;
      // Only with a power-up mode, never empty, no kinds the link's app didn't have.
      if (mode == MatchMode.threads ||
          mask == null ||
          mask <= BigInt.zero ||
          mask.bitLength > kindCount!) {
        return null;
      }
      powerUps = {
        for (final k in PowerUpKind.values)
          if (k.index < kindCount && (mask >> k.index).isOdd) k,
      };
    } else if (mode != MatchMode.threads &&
        kindCount! < PowerUpKind.values.length) {
      powerUps = {
        for (final k in PowerUpKind.values)
          if (k.index < kindCount) k,
      };
    }
    final mayhem = params['mayhem'] == '1';
    final mayhemSeconds = int.tryParse(params['duration'] ?? '120');
    if (mayhemSeconds == null ||
        mayhemSeconds < 30 ||
        mayhemSeconds > 1800 ||
        (params.containsKey('duration') && !mayhem)) {
      return null;
    }
    if (params.containsKey('mayhem') && params['mayhem'] != '1') return null;
    if (seed == null ||
        tokens.length < minBalls ||
        tokens.length > (mayhem ? mayhemBalls : maxBalls)) {
      return null;
    }
    if (!speed.isFinite || speed < minSpeed || speed > maxSpeed) return null;
    final ballSize = params['size'] == null
        ? BallSize.medium
        : BallSize.byId(params['size']);
    if (ballSize == null) return null;
    var nudgeSteps = const <int>[];
    final nudge = params['nudge'];
    if (nudge != null) {
      final steps = [for (final part in nudge.split(',')) int.tryParse(part)];
      // Positive steps within an hour of game time, at most 200 of them.
      if (steps.length > 200 ||
          steps.any((s) => s == null || s < 1 || s > maxLinkStep)) {
        return null;
      }
      nudgeSteps = [...steps.cast<int>()]..sort();
    }
    Set<String>? customSkills;
    final cs = params['cs'];
    if (cs != null) {
      // Only with a power-up mode; only ids the app makes (custom.<slug>), and not too many.
      if (mode == MatchMode.threads) return null;
      final ids = cs.split(',').where((id) => id.isNotEmpty).toSet();
      final valid = RegExp(r'^custom\.[a-z0-9-]{1,80}$');
      if (ids.length > 64 || !ids.every(valid.hasMatch)) return null;
      customSkills = ids;
    }
    final dualWield = params['dw'] == '1';
    if (params.containsKey('dw') && params['dw'] != '1') return null;
    if (mode == MatchMode.threads && dualWield) return null;
    final endlessBattle = params['endless'] == '1';
    if (params.containsKey('endless') && params['endless'] != '1') return null;
    if (mode != MatchMode.arsenal && endlessBattle) return null;
    if (mayhem &&
        (mode != MatchMode.arsenal ||
            !endlessBattle ||
            tokens.length != mayhemBalls)) {
      return null;
    }
    int? endStep;
    final end = params['end'];
    if (end != null) {
      // Only with an endless (non-Mayhem) battle; a step within an hour of game time.
      endStep = int.tryParse(end);
      if (!endlessBattle ||
          mayhem ||
          endStep == null ||
          endStep < 1 ||
          endStep > maxLinkStep) {
        return null;
      }
    }
    final shrinkingArena = params['shrink'] == '1';
    if (params.containsKey('shrink') && params['shrink'] != '1') return null;
    final minimumArenaScale = double.tryParse(params['minarena'] ?? '0.60');
    if (minimumArenaScale == null ||
        !minimumArenaScale.isFinite ||
        minimumArenaScale < 0.40 ||
        minimumArenaScale > 0.90 ||
        (!shrinkingArena && params.containsKey('minarena'))) {
      return null;
    }
    final automaticSpeedUp = params['autospeed'] != '0';
    if (params.containsKey('autospeed') && params['autospeed'] != '0') {
      return null;
    }
    final arenaDecoration = params['arena'] == null
        ? ArenaDecoration.defaultArena
        : ArenaDecoration.values
              .where((value) => value.name == params['arena'])
              .firstOrNull;
    if (arenaDecoration == null) return null;
    final ballGlowWidth = double.tryParse(params['glow'] ?? '4');
    if (ballGlowWidth == null ||
        !ballGlowWidth.isFinite ||
        ballGlowWidth < 1 ||
        ballGlowWidth > 12) {
      return null;
    }
    final bloodValue = params['blood'] == null
        ? 0xFFD9152B
        : int.tryParse(params['blood']!, radix: 16);
    if (bloodValue == null) return null;
    final randomizedHairstyles = params['hair'] == '1';
    if (params.containsKey('hair') && params['hair'] != '1') return null;
    var tuning = PowerUpConfig.defaults;
    final t = params['t'];
    if (t != null) {
      // Only with a power-up mode, and only something PowerUpConfig.encode could have made.
      final decoded = mode == MatchMode.threads
          ? null
          : PowerUpConfig.decode(t);
      if (decoded == null) return null;
      tuning = decoded;
    }
    var skillLibrary = SkillLibrary.defaults;
    final skills = params['skills'];
    if (skills != null) {
      if (mode == MatchMode.threads) return null;
      final decoded = SkillLibrary.decodeReplay(skills);
      if (decoded == null) return null;
      skillLibrary = decoded;
    }

    final artworkRevisions = ReplayAssets.decode(
      params['assets'],
      skillLibrary,
    );
    if (artworkRevisions == null) return null;
    final contestants = <CustomBall>[];
    for (var i = 0; i < tokens.length; i++) {
      final ball = _decodeBall(tokens[i], i, presets, packBalls);
      if (ball == null) return null;
      contestants.add(ball);
    }
    return ReplayLink(
      simulationRevision: simulationRevision,
      seed: seed,
      speedMultiplier: speed,
      automaticSpeedUp: automaticSpeedUp,
      contestants: contestants,
      showEffects: params['fx'] != '0',
      effectRenderMode: EffectRenderMode.values
          .where((mode) => mode.name == params['effectvisuals'])
          .firstOrNull,
      ballGlowWidth: ballGlowWidth,
      bloodColor: Color(bloodValue),
      randomizedHairstyles: randomizedHairstyles,
      ballSize: ballSize,
      mode: mode,
      question: cleanQuestion(params['q']),
      look: BallLook.byName(params['look']),
      powerUps: powerUps,
      customSkills: customSkills,
      nudgeSteps: nudgeSteps,
      endStep: endStep,
      tuning: tuning,
      dualWield: dualWield,
      endlessBattle: endlessBattle,
      mayhem: mayhem,
      mayhemSeconds: mayhemSeconds,
      shrinkingArena: shrinkingArena,
      minimumArenaScale: minimumArenaScale,
      arenaDecoration: arenaDecoration,
      skillLibrary: skillLibrary,
      artworkRevisions: artworkRevisions.ids,
      artworkFrames: artworkRevisions.embedded,
    );
  }

  /// A short link `<app>?r=<code>` (see ShortLinkRepository).
  static Uri shortUri(String code, {String? appUrl}) => Uri.parse(
    '${Uri.parse(appUrl ?? defaultAppUrl).replace(query: '', fragment: '').toString().replaceAll(RegExp(r'[?#]+$'), '')}?r=$code',
  );

  /// The short-link code in [uri], if it is one.
  static String? shortCode(Uri uri) {
    final code = uri.queryParameters['r'];
    return code != null && RegExp(r'^[A-Za-z0-9]{7}$').hasMatch(code)
        ? code
        : null;
  }

  /// A link that lets anyone add the group [groupId] to their categories:
  /// `<app>?g=<group uuid>`.
  static Uri groupUri(String groupId, {String? appUrl}) => Uri.parse(
    '${Uri.parse(appUrl ?? defaultAppUrl).replace(query: '', fragment: '').toString().replaceAll(RegExp(r'[?#]+$'), '')}?g=$groupId',
  );

  /// The group id in a group share link, if [uri] is one.
  static String? sharedGroupId(Uri uri) {
    final id = uri.queryParameters['g'];
    return id != null && RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id)
        ? id.toLowerCase()
        : null;
  }

  /// The running page's address on web (so local builds link to themselves).
  static String get defaultAppUrl {
    if (!kIsWeb) return kWebAppUrl;
    return Uri.base
        .replace(query: '', fragment: '')
        .toString()
        .replaceAll(RegExp(r'[?#]+$'), '');
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
            // Gender (cosmetic: the hair pool), only when set, so links of
            // balls without one stay as they were.
            if (b.gender != BallGender.none) 'x': b.gender.name,
          }),
        ),
      )
      .replaceAll('=', '');

  /// The ball tokens of a replay link in [uri] (empty if it isn't one).
  static List<String> ballTokens(Uri uri) => _params(uri)['seed'] == null
      ? const []
      : (_params(uri)['balls'] ?? '')
            .split(',')
            .where((t) => t.isNotEmpty)
            .toList();

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
      uri.fragment.startsWith('/replay')
      ? Uri.parse(uri.fragment).queryParameters
      : uri.queryParameters;

  static const int minBalls = 2;
  static const int maxBalls = 4;
  static const int mayhemBalls = 6;
  static const double minSpeed = 0.25;
  static const double maxSpeed = 4;

  /// Longest accepted query (four custom balls fit easily).
  static const int maxLinkLength = 524288;
  static const int maxNameLength = 40;

  static bool _within(double v, double min, double max) =>
      v.isFinite && v >= min && v <= max;

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
    if (token.startsWith('k.')) {
      return packBalls['$_packPrefix${token.substring(2)}'];
    }
    if (token.startsWith('g.')) {
      return packBalls['$_groupPrefix${token.substring(2)}'];
    }
    if (!token.startsWith('c.')) return null;
    try {
      final raw = token.substring(2);
      final padded = raw.padRight((raw.length + 3) ~/ 4 * 4, '=');
      final data =
          jsonDecode(utf8.decode(base64Url.decode(padded)))
              as Map<String, dynamic>;
      final name = (data['n'] as String).trim();
      final baseSpeed = (data['s'] as num).toDouble();
      final mass = (data['m'] as num).toDouble();
      // Within 4x either way of the defaults; anything else is not from the app.
      if (name.isEmpty || name.length > maxNameLength) return null;
      if (!_within(
        baseSpeed,
        CustomBall.defaultBaseSpeed / 4,
        CustomBall.defaultBaseSpeed * 4,
      )) {
        return null;
      }
      if (!_within(mass, 0.25, 4)) return null;
      final rawGender = data['x'];
      BallGender gender = BallGender.none;
      if (rawGender != null) {
        // Only what the app writes: "male" or "female" (none is left out).
        if (rawGender is! String) return null;
        final match = BallGender.values.where(
          (g) => g != BallGender.none && g.name == rawGender,
        );
        if (match.isEmpty) return null;
        gender = match.first;
      }
      return CustomBall(
        id: 'link-$index',
        name: name,
        primaryColor: Color(data['p'] as int),
        glowColor: Color(data['g'] as int),
        baseSpeed: baseSpeed,
        mass: mass,
        gender: gender,
      );
    } catch (_) {
      return null;
    }
  }
}
