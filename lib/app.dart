import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/audio/game_audio.dart';
import 'core/offline/device_prefs.dart';
import 'core/offline/offline_sync.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/ball_wars_logo.dart';
import 'features/arena_simulation/presentation/arena_battle_screen.dart';
import 'features/ball_management/data/local_ball_repository.dart';
import 'features/ball_management/domain/custom_ball.dart';
import 'features/ball_management/presentation/widgets/circular_ball_preview.dart';
import 'features/ball_packs/data/ball_pack_repository.dart';
import 'features/custom_groups/data/custom_group_repository.dart';
import 'features/custom_groups/domain/custom_group.dart';
import 'features/custom_groups/presentation/my_groups_screen.dart';
import 'features/match_setup/domain/match_config.dart';
import 'features/match_setup/presentation/match_setup_screen.dart';
import 'features/replay_export/data/short_link_repository.dart';
import 'features/replay_export/domain/replay_link.dart';
import 'features/settings/data/app_settings_repository.dart';
import 'features/settings/domain/app_settings.dart';
import 'features/settings/presentation/app_settings_scope.dart';
import 'features/settings/presentation/settings_screen.dart';

class BallWarsApp extends StatefulWidget {
  /// User-made groups (Supabase); null hides My Groups (e.g. in tests).
  final CustomGroupRepository? customGroups;

  /// The same groups through the admin's session, for editing anyone's.
  final CustomGroupRepository? adminGroups;

  /// App-wide settings and the admin login; null keeps the defaults.
  final AppSettingsRepository? settingsRepository;
  final AdminAuth? adminAuth;

  /// Short share links; null shares long links only.
  final ShortLinkRepository? shortLinks;

  /// Download every ball image at startup (behind a loading screen) so the
  /// app works offline; off in tests.
  final bool syncOffline;

  const BallWarsApp({
    super.key,
    this.customGroups,
    this.adminGroups,
    this.settingsRepository,
    this.adminAuth,
    this.shortLinks,
    this.syncOffline = false,
  });

  @override
  State<BallWarsApp> createState() => _BallWarsAppState();
}

class _BallWarsAppState extends State<BallWarsApp> {
  final ValueNotifier<AppSettings> _settings = ValueNotifier(
    AppSettings.defaults,
  );

  // Built-in packs (Streaming, Countries, ...), loaded once and shared.
  final BallPackRepository _packs = BallPackRepository();

  /// (downloaded, to download) while ball images are saved for offline play
  /// in the background; null once done.
  final ValueNotifier<(int, int)?> _progress = ValueNotifier(null);
  late final Future<void> _ready = _prepare();

  @override
  void initState() {
    super.initState();
    // The admin's music choice applies to every player's matches.
    _settings.addListener(_applyMusic);
  }

  void _applyMusic() {
    GameAudio.instance.track = MusicTrack.byId(_settings.value.musicId);
    GameAudio.instance.menuTrack = MusicTrack.menuById(
      _settings.value.menuMusicId,
    );
  }

  /// Waits only for the settings (theme, headline) and the pack catalog;
  /// the ball images then download in the background while Home shows their
  /// progress, so a slow host never holds up the start.
  Future<void> _prepare() async {
    await Future.wait([
      _loadSettings(),
      if (widget.syncOffline)
        _packs.load().then((_) {}, onError: (Object _) {}),
    ]);
    if (!widget.syncOffline) return;
    OfflineSync(packs: _packs, groups: widget.customGroups)
        .run(
          onProgress: (done, total) {
            if (mounted) _progress.value = (done, total);
          },
        )
        .whenComplete(() {
          if (mounted) _progress.value = null;
        });
  }

  Future<void> _loadSettings() async {
    final repo = widget.settingsRepository;
    if (repo == null) return;
    try {
      _settings.value = await repo.load();
    } catch (_) {
      // Offline or not set up yet: keep the defaults.
    }
  }

  @override
  void dispose() {
    _settings.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      settings: _settings,
      repository: widget.settingsRepository,
      adminAuth: widget.adminAuth,
      shortLinks: widget.shortLinks,
      child: ValueListenableBuilder<AppSettings>(
        valueListenable: _settings,
        builder: (context, settings, _) => MaterialApp(
          title: 'Ball Wars',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(AppPalettes.byId(settings.themeId)),
          home: FutureBuilder<void>(
            future: _ready,
            builder: (context, snapshot) =>
                snapshot.connectionState == ConnectionState.done
                ? _HomeScreen(
                    packs: _packs,
                    customGroups: widget.customGroups,
                    adminGroups: widget.adminGroups,
                    shortLinks: widget.shortLinks,
                    offlineProgress: _progress,
                  )
                : const _LoadingScreen(),
          ),
        ),
      ),
    );
  }
}

/// Shown at startup while the settings and pack catalog load. The logo sits
/// where the native splash screen has it, so one follows the other.
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: SizedBox.square(
              dimension: 116,
              child: CustomPaint(
                painter: BallWarsLogoPainter(
                  background: c.background,
                  rim: c.text,
                ),
              ),
            ),
          ),
          Positioned(
            left: 48,
            right: 48,
            bottom: 72,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    color: c.text,
                    backgroundColor: c.surfaceHigh,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Home's "Saving balls for offline… 120/359" line while images download.
class _OfflineProgress extends StatelessWidget {
  final ValueListenable<(int, int)?> progress;

  const _OfflineProgress(this.progress);

  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    return ValueListenableBuilder<(int, int)?>(
      valueListenable: progress,
      builder: (context, p, _) {
        if (p == null || p.$2 == 0 || p.$1 >= p.$2) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Saving balls for offline…',
                      style: AppText.ui(12, FontWeight.w600, color: c.muted),
                    ),
                  ),
                  Text(
                    '${p.$1}/${p.$2}',
                    style: AppText.mono(11, color: c.muted),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: p.$1 / p.$2,
                  minHeight: 2,
                  color: c.muted,
                  backgroundColor: c.surfaceHigh,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeScreen extends StatefulWidget {
  final BallPackRepository packs;
  final CustomGroupRepository? customGroups;
  final CustomGroupRepository? adminGroups;
  final ShortLinkRepository? shortLinks;

  /// Background download of ball images (null when not syncing).
  final ValueListenable<(int, int)?>? offlineProgress;

  const _HomeScreen({
    required this.packs,
    this.customGroups,
    this.adminGroups,
    this.shortLinks,
    this.offlineProgress,
  });

  @override
  State<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<_HomeScreen> {
  BallPackRepository get _packs => widget.packs;
  String _version = '1.14.11';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    }).catchError((Object _) {});
    // Home music plays everywhere outside matches (browsers start it on the
    // first tap; see GameAudio.click).
    GameAudio.instance.startMenuMusic();
    // Opened from a shared replay link (web): go straight to that match.
    _openReplayLink(Uri.base);
    // Or from a group share link: offer to add that group.
    _openGroupLink(Uri.base);
  }

  Future<void> _openGroupLink(Uri uri) async {
    final id = ReplayLink.sharedGroupId(uri);
    final repo = widget.customGroups;
    if (id == null || repo == null) return;
    CustomGroup? group;
    var alreadySaved = false;
    String? problem;
    try {
      group = await repo.group(id);
      if (group == null) {
        problem = 'That shared group no longer exists.';
      } else if (group.ownerId == repo.userId) {
        problem = 'That link is for one of your own groups.';
      } else {
        alreadySaved = (await repo.savedGroups()).any((g) => g.id == id);
      }
    } catch (_) {
      problem = "Couldn't open the shared group. Check your connection.";
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (problem != null || alreadySaved) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            problem ?? '"${group!.name}" is already in your categories.',
          ),
        ),
      );
      return;
    }
    final add = await showDialog<bool>(
      context: context,
      builder: (context) {
        final c = BallWarsColors.of(context);
        return AlertDialog(
          title: Text('Add "${group!.name}"?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final b in group.balls.take(10))
                    CircularBallPreview(ball: b, size: 40),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '${group.balls.length} balls from another player. The group shows up in your categories, marked Shared.',
                style: AppText.ui(
                  14,
                  FontWeight.w500,
                  color: c.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    if (add != true) return;
    try {
      await repo.saveGroup(id);
      messenger.showSnackBar(
        SnackBar(content: Text('Added "${group!.name}" to your categories.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("Couldn't add the group: $e")),
      );
    }
  }

  Future<void> _openReplayLink(Uri uri) async {
    // A short link (?r=<code>) first becomes the long link it stands for.
    final code = ReplayLink.shortCode(uri);
    if (code != null && widget.shortLinks != null) {
      try {
        final query = await widget.shortLinks!.resolve(code);
        if (query == null) return;
        uri = uri.replace(queryParameters: query);
      } catch (_) {
        return;
      }
    }
    final tokens = ReplayLink.ballTokens(uri);
    if (tokens.isEmpty) return;
    var extraBalls = const <String, CustomBall>{};
    try {
      extraBalls = {
        if (tokens.any(ReplayLink.isPackToken))
          for (final pack in await _packs.load())
            for (final b in pack.balls) b.id: b,
        if (widget.customGroups != null && tokens.any(ReplayLink.isGroupToken))
          for (final b in await widget.customGroups!.ballsById(
            ReplayLink.groupBallIds(uri),
          ))
            b.id: b,
      };
    } catch (_) {
      return; // Packs or groups unreachable: stay on the home screen.
    }
    final link = ReplayLink.fromUri(
      uri,
      presets: LocalBallRepository.presets,
      packBalls: extraBalls,
    );
    if (link == null) return;
    // The ball look is the viewer's own choice (cosmetic, not in links).
    final look =
        BallLook.byName(await DevicePrefs.read('look')) ?? BallLook.pictures;
    final wallSparkSize =
        WallSparkSize.byId(await DevicePrefs.read('wall-spark-size')) ??
        WallSparkSize.normal;
    // endOfFrame (not addPostFrameCallback): after the awaits above the first
    // frame is long done and an idle screen never draws another one, so a
    // post-frame callback would never run. endOfFrame schedules a frame.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArenaBattleScreen(
          config: MatchConfig(
            contestants: link.contestants,
            speedMultiplier: link.speedMultiplier,
            ballSize: link.ballSize,
            mode: link.mode,
            question: link.question,
            powerUps: link.powerUps,
            tuning: link.tuning,
            dualWield: link.dualWield,
            endlessBattle: link.endlessBattle,
            mayhem: link.mayhem,
            mayhemSeconds: link.mayhemSeconds,
            shrinkingArena: link.shrinkingArena,
            minimumArenaScale: link.minimumArenaScale,
            showEffects: link.showEffects,
            look: look,
            wallSparkSize: wallSparkSize,
          ),
          seed: link.seed,
        ),
      ),
    );
  }

  void _openMatchSetup([MatchMode mode = MatchMode.threads, bool mayhem = false]) {
    GameAudio.instance.click();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchSetupScreen(
          packRepository: _packs,
          initialMode: mode,
          initialMayhem: mayhem,
          customGroups: widget.customGroups,
          onStartBattle: (config) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ArenaBattleScreen(config: config),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    final customGroups = widget.customGroups;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        'BALL WARS',
                        style: AppText.ui(
                          15,
                          FontWeight.w800,
                          color: c.text,
                          letterSpacing: 2.6,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: GameAudio.instance.menuMusicOn
                            ? 'Home music: on'
                            : 'Home music: off',
                        icon: Icon(
                          GameAudio.instance.menuMusicOn
                              ? Icons.music_note_rounded
                              : Icons.music_off_rounded,
                          color: GameAudio.instance.menuMusicOn
                              ? c.text
                              : c.muted,
                        ),
                        onPressed: () async {
                          await GameAudio.instance.setMenuMusicOn(
                            !GameAudio.instance.menuMusicOn,
                          );
                          GameAudio.instance.click();
                          if (mounted) setState(() {});
                        },
                      ),
                      IconButton(
                        tooltip: 'Settings',
                        icon: const Icon(Icons.tune),
                        onPressed: () {
                          GameAudio.instance.click();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SettingsScreen(
                                customGroups: customGroups,
                                adminGroups: widget.adminGroups,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  if (widget.offlineProgress != null)
                    _OfflineProgress(widget.offlineProgress!),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: CustomPaint(
                          painter: _HomeArenaPainter(rim: c.text),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    AppSettingsScope.of(
                      context,
                    ).headline.toLowerCase().replaceFirstMapped(
                      RegExp(r'^\w'),
                      (m) => m[0]!.toUpperCase(),
                    ),
                    style: AppText.ui(
                      40,
                      FontWeight.w800,
                      color: c.text,
                      height: 1.05,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Pick two to four balls. Each holds a fan of lines to the rim - cut them all and it\'s out.',
                    style: AppText.ui(
                      15,
                      FontWeight.w500,
                      color: c.muted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text('Version $_version', textAlign: TextAlign.center,
                    style: AppText.ui(12, FontWeight.w500, color: c.muted)),
                  const SizedBox(height: 8),
                  Column(children: [
                    Row(children: [
                      Expanded(child: FilledButton(
                        onPressed: () => _openMatchSetup(MatchMode.threads),
                        child: const Text('Threads'))),
                      const SizedBox(width: 8),
                      Expanded(child: FilledButton(
                        onPressed: () => _openMatchSetup(MatchMode.arsenal),
                        child: const Text('Arsenal'))),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: FilledButton(
                        onPressed: () => _openMatchSetup(MatchMode.arsenal, true),
                        child: const Text('Mayhem'))),
                      const SizedBox(width: 8),
                      Expanded(child: FilledButton(
                        onPressed: () => _openMatchSetup(MatchMode.allOut),
                        child: const Text('All-Out'))),
                    ]),
                  ]),
                  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
                    TextButton.icon(onPressed: () => SystemNavigator.pop(),
                      icon: const Icon(Icons.exit_to_app), label: const Text('Quit game')),
                  if (customGroups != null) ...[
                    const SizedBox(height: 12),
                    _HomeTile(
                      title: 'My groups',
                      subtitle: 'Your own categories of balls',
                      onTap: () {
                        GameAudio.instance.click();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                MyGroupsScreen(repository: customGroups),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HomeTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.ui(14, FontWeight.w700, color: c.text),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppText.ui(12, FontWeight.w500, color: c.muted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: c.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// The home screen's arena illustration: a rim and two fans of lines.
class _HomeArenaPainter extends CustomPainter {
  final Color rim;

  _HomeArenaPainter({required this.rim});

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2 - 4;
    final center = size.center(Offset.zero);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = rim,
    );
    void fan(Offset ball, Color color, double fromDeg, double toDeg) {
      final paint = Paint()
        ..color = color.withValues(alpha: 0.85)
        ..strokeWidth = 1;
      for (var i = 0; i < 13; i++) {
        final a = (fromDeg + (toDeg - fromDeg) * i / 12) * math.pi / 180;
        canvas.drawLine(
          center + Offset(math.cos(a), math.sin(a)) * r,
          ball,
          paint,
        );
      }
      canvas.drawCircle(ball, r * 0.1, Paint()..color = rim);
      canvas.drawCircle(
        ball,
        r * 0.1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = color,
      );
    }

    fan(
      center + Offset(r * 0.25, -r * 0.32),
      const Color(0xFF4FD1C5),
      200,
      330,
    );
    fan(center + Offset(-r * 0.29, r * 0.29), const Color(0xFFFF7A59), 15, 150);
  }

  @override
  bool shouldRepaint(_HomeArenaPainter oldDelegate) => oldDelegate.rim != rim;
}
