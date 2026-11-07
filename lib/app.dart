import 'core/theme/ui_skin.dart';
import 'core/theme/ui_skin_scope.dart';
import 'core/theme/garage_theme.dart';
import 'core/legal/app_licenses.dart';
import 'core/theme/game_ui.dart';
import 'features/lobby/presentation/lobby_hero.dart';
import 'dart:async';
import 'features/arena_simulation/presentation/power_up_sprites.dart';
import 'core/widgets/app_frame.dart';
import 'core/sprites/visual_quality.dart';
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
import 'features/replay_export/data/saved_replay_store.dart';
import 'features/replay_export/presentation/saved_replays_screen.dart';
import 'features/settings/data/app_settings_repository.dart';
import 'features/settings/domain/app_settings.dart';
import 'features/settings/presentation/app_settings_scope.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/sprites/data/sprite_atlas_repository.dart';
import 'features/sprites/application/custom_sprite_loader.dart';
import 'features/sprites/application/skill_sprite_readiness.dart';

class BallWarsApp extends StatefulWidget {
  /// User-made groups (Supabase); null hides My Groups (e.g. in tests).
  final CustomGroupRepository? customGroups;

  /// The same groups through the admin's session, for editing anyone's.
  final CustomGroupRepository? adminGroups;

  /// App-wide settings and the admin login; null keeps the defaults.
  final AppSettingsRepository? settingsRepository;
  final AdminAuth? adminAuth;
  final SpriteAtlasRepository? sprites;

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
    this.sprites,
    this.shortLinks,
    this.syncOffline = false,
  });

  @override
  State<BallWarsApp> createState() => _BallWarsAppState();
}

class _BallWarsAppState extends State<BallWarsApp> {
  final _uiSkin = UiSkinController();
  CustomSpriteLoader? _spriteLoader;
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
    AppLicenses.register();
    VisualQuality.load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        PowerUpSprites.load().catchError((Object error) {
          debugPrint('Background artwork warm-up failed: $error');
        }),
      );
    });
    // The admin's music choice applies to every player's matches.
    _settings.addListener(_applyMusic);
    if (widget.sprites != null) {
      final loader = CustomSpriteLoader(widget.sprites!);
      _spriteLoader = loader;
      SkillSpriteReadiness.loader = loader;
      loader.load();
    }
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
      _uiSkin.load(),
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
    if (identical(SkillSpriteReadiness.loader, _spriteLoader)) {
      SkillSpriteReadiness.loader = null;
    }
    _uiSkin.dispose();
    _settings.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UiSkinHost(
      controller: _uiSkin,
      load: false,
      child: Builder(builder: _buildApplication),
    );
  }

  Widget _buildApplication(BuildContext context) {
    final garage = UiSkinScope.of(context) == UiSkin.garage;
    return AppSettingsScope(
      settings: _settings,
      repository: widget.settingsRepository,
      adminAuth: widget.adminAuth,
      shortLinks: widget.shortLinks,
      sprites: widget.sprites,
      child: ValueListenableBuilder<AppSettings>(
        valueListenable: _settings,
        builder: (context, settings, _) => MaterialApp(
          title: 'Ball Wars',
          builder: (context, child) =>
              AppFrame(child: child ?? const SizedBox.shrink()),
          debugShowCheckedModeBanner: false,
          theme: garage
              ? GarageTheme.apply(
                  AppTheme.build(AppPalettes.byId(settings.themeId)),
                )
              : AppTheme.build(AppPalettes.byId(settings.themeId)),
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
  String _version = '...';
  int _savedReplayCount = 0;
  bool _savedReplayReadFailed = false;
  MatchMode _lastMode = MatchMode.threads;
  bool _lastMayhem = false, _modeChosen = false;
  Future<void> _restoreLobbyMode() async {
    final mode = MatchMode.byId(await DevicePrefs.read('lobby-mode'));
    final mayhem = await DevicePrefs.read('lobby-mayhem') == '1';
    if (mounted && !_modeChosen) {
      setState(() {
        _lastMode = mode ?? MatchMode.threads;
        _lastMayhem = mayhem && _lastMode == MatchMode.arsenal;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _restoreLobbyMode();
    PackageInfo.fromPlatform()
        .then((info) {
          if (mounted) setState(() => _version = info.version);
        })
        .catchError((Object _) {});
    // Home music plays everywhere outside matches (browsers start it on the
    // first tap; see GameAudio.click).
    GameAudio.instance.startMenuMusic();
    // Opened from a shared replay link (web): go straight to that match.
    _openReplayLink(Uri.base);
    SavedReplayStore.load()
        .then((entries) {
          if (mounted) {
            setState(() {
              _savedReplayCount = entries.length;
              _savedReplayReadFailed = false;
            });
          }
        })
        .catchError((Object _) {
          if (mounted) setState(() => _savedReplayReadFailed = true);
        });
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

  Future<void> _replayProblem(
    String message,
    Uri uri, {
    bool retry = false,
  }) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: retry
            ? SnackBarAction(
                label: 'Retry',
                onPressed: () => _openReplayLink(uri),
              )
            : null,
      ),
    );
  }

  Future<void> _openReplayLink(Uri uri) async {
    final originalUri = uri;
    // A short link (?r=<code>) first becomes the long link it stands for.
    final code = ReplayLink.shortCode(uri);
    if (code != null && widget.shortLinks != null) {
      try {
        final query = await widget.shortLinks!.resolve(code);
        if (query == null) {
          await _replayProblem(
            'This replay link no longer exists.',
            originalUri,
          );
          return;
        }
        uri = uri.replace(queryParameters: query);
      } catch (_) {
        await _replayProblem(
          'Could not load this replay. Check your connection.',
          originalUri,
          retry: true,
        );
        return;
      }
    } else if (code != null) {
      await _replayProblem(
        'Replay sharing is unavailable. Try again when connected.',
        originalUri,
        retry: true,
      );
      return;
    }
    final tokens = ReplayLink.ballTokens(uri);
    if (tokens.isEmpty) {
      if (uri.queryParameters.containsKey('balls') ||
          uri.queryParameters.containsKey('seed') ||
          uri.queryParameters.containsKey('r')) {
        await _replayProblem(
          'This replay is invalid or uses an unsupported format.',
          originalUri,
        );
      }
      return;
    }
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
      await _replayProblem(
        'Could not load the balls for this replay. Check your connection.',
        originalUri,
        retry: true,
      );
      return;
    }
    final link = ReplayLink.fromUri(
      uri,
      presets: LocalBallRepository.presets,
      packBalls: extraBalls,
    );
    if (link == null) {
      await _replayProblem(
        'This replay is invalid, unsupported, or has unavailable balls.',
        originalUri,
      );
      return;
    }
    // The look the match was played with (saved replays and newer links); older links without it use
    // the viewer's own choice.
    final look =
        link.look ??
        BallLook.byName(await DevicePrefs.read('look')) ??
        BallLook.pictures;
    final handsOnPictures = await DevicePrefs.read('hands-on-pictures') == '1';
    final whitePickupBackgrounds =
        await DevicePrefs.read('white-pickup-backgrounds') != '0';
    // The viewer's own HP bars choice for that match type (cosmetic, not in links).
    final hpBars =
        await DevicePrefs.read(
          'match-${link.mayhem ? 'mayhem' : link.mode.id}-hp-bars',
        ) ==
        '1';
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
            simulationRevision: link.simulationRevision,
            contestants: link.contestants,
            speedMultiplier: link.speedMultiplier,
            automaticSpeedUp: link.automaticSpeedUp,
            ballSize: link.ballSize,
            mode: link.mode,
            threadGrowthMaxThreads: link.threadGrowthMaxThreads,
            neoThreadsTarget: link.neoThreadsTarget,
            threadCutRace: link.threadCutRace,
            cutRaceSurvival: link.cutRaceSurvival,
            question: link.question,
            powerUps: link.powerUps,
            customSkills: link.customSkills,
            tuning: link.tuning,
            skillLibrary: link.skillLibrary,
            artworkRevisions: link.artworkRevisions,
            artworkFrames: link.artworkFrames,
            dualWield: link.dualWield,
            endlessBattle: link.endlessBattle,
            mayhem: link.mayhem,
            mayhemSeconds: link.mayhemSeconds,
            shrinkingArena: link.shrinkingArena,
            minimumArenaScale: link.minimumArenaScale,
            arenaPreset: link.arenaPreset,
            arenaDecoration: link.arenaDecoration,
            arenaShape: link.arenaShape,
            centerObstacle: link.centerObstacle,
            centerObstacleScale: link.centerObstacleScale,
            arenaRotation: link.arenaRotation,
            showEffects: link.showEffects,
            effectRenderMode: link.effectRenderMode,
            ballGlowWidth: link.ballGlowWidth,
            bloodColor: link.bloodColor,
            randomizedHairstyles: link.randomizedHairstyles,
            look: look,
            handsOnPictures: handsOnPictures,
            showHpBars: hpBars,
            showBallNames: link.showBallNames,
            whitePickupBackgrounds: whitePickupBackgrounds,
            wallSparkSize: wallSparkSize,
          ),
          seed: link.seed,
          nudgeSteps: link.nudgeSteps,
          endStep: link.endStep,
        ),
      ),
    );
  }

  void _openMatchSetup([
    MatchMode mode = MatchMode.threads,
    bool mayhem = false,
  ]) {
    _modeChosen = true;
    setState(() {
      _lastMode = mode;
      _lastMayhem = mayhem;
    });
    DevicePrefs.write('lobby-mode', mode.id);
    DevicePrefs.write('lobby-mayhem', mayhem ? '1' : '0');
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
  Widget build(BuildContext context) =>
      GameTheme(child: Builder(builder: _buildLobby));

  Widget _buildLobby(BuildContext context) {
    final customGroups = widget.customGroups;
    Widget mode(
      String title,
      String subtitle,
      IconData icon,
      Color accent,
      MatchMode value, {
      bool mayhem = false,
    }) => GameModeTile(
      title: title,
      subtitle: subtitle,
      icon: icon,
      accent: accent,
      selected: _lastMode == value && _lastMayhem == mayhem,
      onTap: () => _openMatchSetup(value, mayhem),
    );
    return Scaffold(
      body: GameBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, bounds) => SingleChildScrollView(
              key: const ValueKey('game-lobby-scroll'),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'BATTLE LOBBY',
                          style: TextStyle(
                            color: GameUi.cyan,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      GameIconButton(
                        tooltip: GameAudio.instance.menuMusicOn
                            ? 'Home music: on'
                            : 'Home music: off',
                        icon: GameAudio.instance.menuMusicOn
                            ? Icons.music_note_rounded
                            : Icons.music_off_rounded,
                        onPressed: () async {
                          await GameAudio.instance.setMenuMusicOn(
                            !GameAudio.instance.menuMusicOn,
                          );
                          GameAudio.instance.click();
                          if (mounted) setState(() {});
                        },
                      ),
                      GameIconButton(
                        tooltip: 'Settings',
                        icon: Icons.tune,
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
                  const Icon(
                    Icons.workspace_premium_rounded,
                    color: GameUi.gold,
                    size: 27,
                  ),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'BALL ',
                          style: TextStyle(
                            color: BallWarsColors.of(context).text,
                          ),
                        ),
                        TextSpan(
                          text: 'WARS',
                          style: TextStyle(color: GameUi.gold),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 43,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.8,
                      shadows: [
                        Shadow(
                          color: Color(0xFF03051B),
                          offset: Offset(0, 4),
                          blurRadius: 1,
                        ),
                        Shadow(color: Color(0x80417AF4), blurRadius: 18),
                      ],
                    ),
                  ),
                  Text(
                    AppSettingsScope.of(
                      context,
                    ).headline.toLowerCase().replaceFirstMapped(
                      RegExp(r'^\w'),
                      (m) => m[0]!.toUpperCase(),
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: BallWarsColors.of(context).muted,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(
                    height: (bounds.maxWidth * .45).clamp(145.0, 200.0),
                    child: const LobbyHero(),
                  ),
                  GameActionButton(
                    key: const ValueKey('lobby-play'),
                    label: 'Play',
                    onPressed: () => _openMatchSetup(_lastMode, _lastMayhem),
                    height: 58,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'CHOOSE YOUR BATTLE',
                    style: TextStyle(
                      color: BallWarsColors.of(context).text,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 9),
                  SizedBox(
                    height: 92,
                    child: Row(
                      children: [
                        Expanded(
                          child: mode(
                            'Arsenal',
                            'Weapon battles',
                            Icons.gps_fixed,
                            GameUi.cyan,
                            MatchMode.arsenal,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: mode(
                            'Mayhem',
                            '6-8 ball chaos',
                            Icons.cyclone,
                            GameUi.purple,
                            MatchMode.arsenal,
                            mayhem: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: mode(
                            'All-Out',
                            'Threads + arms',
                            Icons.local_fire_department,
                            GameUi.orange,
                            MatchMode.allOut,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 82,
                    child: Row(
                      children: [
                        Expanded(
                          child: mode(
                            'Threads',
                            'The original',
                            Icons.hub_outlined,
                            GameUi.cyan,
                            MatchMode.threads,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: mode(
                            'Neo Threads',
                            'Grow. Cut. Survive.',
                            Icons.auto_awesome,
                            GameUi.purple,
                            MatchMode.threadGrowth,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (customGroups != null) ...[
                          Expanded(
                            child: _HomeTile(
                              icon: Icons.groups_outlined,
                              title: 'My groups',
                              subtitle: 'Your balls',
                              onTap: () {
                                GameAudio.instance.click();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => MyGroupsScreen(
                                      repository: customGroups,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: _HomeTile(
                            icon: Icons.video_library_outlined,
                            title: 'Saved replays',
                            subtitle: _savedReplayReadFailed
                                ? 'Could not load. Tap to retry.'
                                : '$_savedReplayCount saved',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SavedReplaysScreen(
                                  onOpen: _openReplayLink,
                                  shortLinks: widget.shortLinks,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Version $_version',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: BallWarsColors.of(context).muted,
                      fontSize: 11,
                    ),
                  ),
                  TextButton(
                    onPressed: () => showLicensePage(
                      context: context,
                      applicationName: 'Ball Wars',
                    ),
                    child: const Text('Credits & licenses'),
                  ),
                  if (!kIsWeb &&
                      defaultTargetPlatform == TargetPlatform.android)
                    TextButton.icon(
                      onPressed: () => SystemNavigator.pop(),
                      icon: const Icon(Icons.exit_to_app, size: 16),
                      label: const Text('Quit game'),
                    ),
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
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HomeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      customBorder: BeveledRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: GamePanel(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: GameUi.cyan, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: BallWarsColors.of(context).text,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: BallWarsColors.of(context).muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
