import 'dart:convert';
import '../../../core/offline/device_prefs.dart';
import '../domain/video_visibility.dart';
import '../../match_setup/domain/arena_rotation.dart';
import '../../settings/presentation/app_settings_scope.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../../match_setup/domain/match_config.dart';
import '../../arena_simulation/application/match_simulation_controller.dart';
import '../../arena_simulation/domain/power_up.dart';
import '../../arena_simulation/domain/power_up_config.dart';
import '../application/replay_video_exporter.dart';
import '../data/video_encoder.dart';
import 'replay_frame_painter.dart';
import '../../skills/domain/skill_library.dart';
import '../../../core/widgets/screen_awake.dart';
import '../../../core/audio/game_audio.dart';
import '../../settings/domain/app_settings.dart';

/// Exports a finished match as a video, saves it to the gallery and offers
/// to share it. Shows progress and can be cancelled.
class ExportVideoDialog extends StatefulWidget {
  final List<CustomBall> contestants;
  final int simulationRevision;
  final int seed;
  final double arenaRadius;
  final double speedMultiplier;
  final bool automaticSpeedUp;
  final bool showEffects;
  final ReplayStyle style;
  final VideoEncoder encoder;

  /// When slow motion starts (the admin's setting), so the video matches.
  final int slowMotionLines;
  final double? slowMotionBeforeWinSeconds;
  final double ballScale;
  final MatchMode mode;
  final int threadGrowthMaxThreads;
  final ArenaShape arenaShape;
  final CenterObstacle centerObstacle;
  final double centerObstacleScale;
  final ArenaRotation arenaRotation;
  final Set<PowerUpKind>? powerUps;
  final Set<String>? customSkills;
  final List<int> nudgeSteps;

  /// End battle step of an endless battle (null if it was never pressed).
  final int? endStep;
  final PowerUpConfig tuning;
  final SkillLibrary skillLibrary;
  final bool endlessBattle;
  final bool dualWield;
  final bool mayhem;
  final int mayhemSeconds;
  final bool shrinkingArena;
  final double minimumArenaScale;
  final bool finishersEnabled;
  final bool randomizedHairstyles;
  final VideoSaver saver;

  const ExportVideoDialog({
    super.key,
    required this.contestants,
    this.simulationRevision = 4,
    required this.seed,
    required this.arenaRadius,
    required this.speedMultiplier,
    this.automaticSpeedUp = true,
    this.showEffects = true,
    this.slowMotionLines = MatchSimulationController.slowMotionLineThreshold,
    this.slowMotionBeforeWinSeconds,
    this.ballScale = 1.0,
    this.mode = MatchMode.threads,
    this.threadGrowthMaxThreads = 180,
    this.arenaShape = ArenaShape.circle,
    this.centerObstacle = CenterObstacle.none,
    this.centerObstacleScale = 0.22,
    this.arenaRotation = const ArenaRotation(),
    this.powerUps,
    this.customSkills,
    this.nudgeSteps = const [],
    this.endStep,
    this.tuning = PowerUpConfig.defaults,
    this.skillLibrary = SkillLibrary.defaults,
    this.endlessBattle = false,
    this.dualWield = false,
    this.mayhem = false,
    this.mayhemSeconds = 120,
    this.shrinkingArena = false,
    this.minimumArenaScale = 0.60,
    this.finishersEnabled = true,
    this.randomizedHairstyles = false,
    this.style = const ReplayStyle(),
    required this.encoder,
    required this.saver,
  });

  static Future<void> show(
    BuildContext context, {
    required List<CustomBall> contestants,
    int simulationRevision = 4,
    required int seed,
    required double arenaRadius,
    required double speedMultiplier,
    bool automaticSpeedUp = true,
    bool showEffects = true,
    EffectRenderMode effectRenderMode = EffectRenderMode.sprite,
    int slowMotionLines = MatchSimulationController.slowMotionLineThreshold,
    double? slowMotionBeforeWinSeconds,
    double ballScale = 1.0,
    MatchMode mode = MatchMode.threads,
    int threadGrowthMaxThreads = 180,
    ArenaShape arenaShape = ArenaShape.circle,
    CenterObstacle centerObstacle = CenterObstacle.none,
    double centerObstacleScale = 0.22,
    ArenaRotation arenaRotation = const ArenaRotation(),
    Set<PowerUpKind>? powerUps,
    Set<String>? customSkills,
    List<int> nudgeSteps = const [],
    int? endStep,
    PowerUpConfig tuning = PowerUpConfig.defaults,
    SkillLibrary skillLibrary = SkillLibrary.defaults,
    Map<String, String> artworkRevisions = const {},
    Map<String, Object> artworkFrames = const {},
    bool endlessBattle = false,
    bool dualWield = false,
    bool mayhem = false,
    int mayhemSeconds = 120,
    bool shrinkingArena = false,
    double minimumArenaScale = 0.60,
    bool finishersEnabled = true,
    bool randomizedHairstyles = false,
    ArenaDecoration arenaDecoration = ArenaDecoration.defaultArena,
    BallLook look = BallLook.pictures,
    bool showHpBars = false,
    String headline = 'WHO WINS?',
    BallWarsColors? colors,
    bool ballGlowEnabled = true,
    double ballGlowWidth = 4,
    Color bloodColor = const Color(0xFFD9152B),
    String arenaTitle = 'dbsuarez',
    String arenaSubtitle = 'bakbakan na',
    required VideoExportBackend backend,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ExportVideoDialog(
        contestants: contestants,
        simulationRevision: simulationRevision,
        seed: seed,
        arenaRadius: arenaRadius,
        speedMultiplier: speedMultiplier,
        automaticSpeedUp: automaticSpeedUp,
        showEffects: showEffects,
        slowMotionLines: slowMotionLines,
        slowMotionBeforeWinSeconds: slowMotionBeforeWinSeconds,
        ballScale: ballScale,
        mode: mode,
        threadGrowthMaxThreads: threadGrowthMaxThreads,
        arenaShape: arenaShape,
        centerObstacle: centerObstacle,
        centerObstacleScale: centerObstacleScale,
        arenaRotation: arenaRotation,
        powerUps: powerUps,
        customSkills: customSkills,
        nudgeSteps: nudgeSteps,
        endStep: endStep,
        tuning: tuning,
        skillLibrary: skillLibrary,
        endlessBattle: endlessBattle,
        dualWield: dualWield,
        mayhem: mayhem,
        mayhemSeconds: mayhemSeconds,
        shrinkingArena: shrinkingArena,
        minimumArenaScale: minimumArenaScale,
        finishersEnabled: finishersEnabled,
        randomizedHairstyles: randomizedHairstyles,
        style: ReplayStyle(
          artworkRevisions: artworkRevisions,
          artworkFrames: artworkFrames,
          effectRenderMode: effectRenderMode,
          headline: headline,
          background: colors?.background ?? const ReplayStyle().background,
          text: colors?.text ?? const ReplayStyle().text,
          muted: colors?.muted ?? const ReplayStyle().muted,
          look: look,
          showHpBars: showHpBars,
          ballGlowEnabled: ballGlowEnabled,
          ballGlowWidth: ballGlowWidth,
          ballAppearance: AppSettingsScope.of(context).ballAppearance,
          bloodColor: bloodColor,
          arenaTitle: arenaTitle,
          arenaSubtitle: arenaSubtitle,
          arenaDecoration: arenaDecoration,
          watermarkText: AppSettingsScope.of(context).exportWatermarkText,
        ),
        encoder: backend,
        saver: backend,
      ),
    );
  }

  @override
  State<ExportVideoDialog> createState() => _ExportVideoDialogState();
}

enum _Phase { options, exporting, saved, failed }

class _ExportVideoDialogState extends State<ExportVideoDialog> {
  _Phase _phase = _Phase.options;
  int _optionsTab = 0;
  VideoVisibility _visibility = const VideoVisibility();
  bool _includeBgm = true;
  bool _includeSfx = true;
  double _progress = 0;
  bool _cancelled = false;
  String? _savedVideo;
  String? _error;
  final Stopwatch _elapsed = Stopwatch();
  Timer? _elapsedTimer;

  @override
  void initState() {
    super.initState();
    final initialLayers = {..._visibility.layers};
    if (!widget.style.showHpBars) initialLayers.remove(VideoLayer.health);
    if (widget.style.look == BallLook.faces) {
      initialLayers.remove(VideoLayer.pictures);
    }
    _visibility = VideoVisibility(layers: Set.unmodifiable(initialLayers));
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final raw = await DevicePrefs.read('video-export-options');
    if (!mounted || raw == null || _phase != _Phase.options) return;
    try {
      final value = jsonDecode(raw);
      if (value is Map) {
        setState(() {
          _visibility = VideoVisibility.fromJson(value['visibility']);
          _includeBgm = value['bgm'] != false;
          _includeSfx = value['sfx'] != false;
        });
      }
    } on FormatException {
      /* Invalid preference only: keep safe defaults. */
    }
  }

  void _startExport() {
    DevicePrefs.write(
      'video-export-options',
      jsonEncode({
        'visibility': _visibility.toJson(),
        'bgm': _includeBgm,
        'sfx': _includeSfx,
      }),
    );
    setState(() => _phase = _Phase.exporting);
    _elapsed.start();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _phase == _Phase.exporting) setState(() {});
    });
    _run();
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _elapsed.stop();
    super.dispose();
  }

  Future<void> _run() async {
    try {
      final path = await ReplayVideoExporter(encoder: widget.encoder).export(
        contestants: widget.contestants,
        simulationRevision: widget.simulationRevision,
        seed: widget.seed,
        arenaRadius: widget.arenaRadius,
        speedMultiplier: widget.speedMultiplier,
        automaticSpeedUp: widget.automaticSpeedUp,
        showEffects: widget.showEffects,
        slowMotionLines: widget.slowMotionLines,
        slowMotionBeforeWinSeconds: widget.slowMotionBeforeWinSeconds,
        ballScale: widget.ballScale,
        mode: widget.mode,
        threadGrowthMaxThreads: widget.threadGrowthMaxThreads,
        arenaShape: widget.arenaShape,
        centerObstacle: widget.centerObstacle,
        centerObstacleScale: widget.centerObstacleScale,
        arenaRotation: widget.arenaRotation,
        powerUps: widget.powerUps,
        customSkills: widget.customSkills,
        nudgeSteps: widget.nudgeSteps,
        endStep: widget.endStep,
        tuning: widget.tuning,
        skillLibrary: widget.skillLibrary,
        endlessBattle: widget.endlessBattle,
        dualWield: widget.dualWield,
        mayhem: widget.mayhem,
        mayhemSeconds: widget.mayhemSeconds,
        shrinkingArena: widget.shrinkingArena,
        minimumArenaScale: widget.minimumArenaScale,
        finishersEnabled: widget.finishersEnabled,
        randomizedHairstyles: widget.randomizedHairstyles,
        includeBgm: _includeBgm,
        includeSfx: _includeSfx,
        bgmAsset: 'assets/${GameAudio.instance.track.asset}',
        bgmLevel: GameAudio.instance.musicLevel,
        sfxLevel: GameAudio.instance.effectsLevel,
        style: widget.style.forVideo(_visibility),
        isCancelled: () => _cancelled,
        confirmDurationLimit: () async {
          if (!mounted || _cancelled) return false;
          return await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('10-minute video limit'),
                  content: const Text(
                    'This replay is longer than 10 minutes at the selected speed. Only the first 10 minutes will be rendered. The final knockout, finisher and winner screen will not be included. Continue with a shortened video?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Back'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Render first 10 minutes'),
                    ),
                  ],
                ),
              ) ??
              false;
        },
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      final saved = await widget.saver.save(path);
      if (mounted) {
        setState(() {
          _savedVideo = saved;
          _phase = _Phase.saved;
        });
      }
    } on ExportCancelled {
      if (mounted && !_cancelled) {
        _elapsedTimer?.cancel();
        _elapsed.stop();
        _elapsed.reset();
        setState(() => _phase = _Phase.options);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _phase = _Phase.failed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => ScreenAwake(
    enabled: _phase == _Phase.exporting,
    child: _buildDialog(context),
  );

  Widget _buildDialog(BuildContext context) {
    switch (_phase) {
      case _Phase.options:
        return AlertDialog(
          title: const Text('SAVE VIDEO'),
          content: SizedBox(
            width: 420,
            height: 420,
            child: Column(
              children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Video')),
                    ButtonSegment(value: 1, label: Text('Audio')),
                  ],
                  selected: {_optionsTab},
                  onSelectionChanged: (value) =>
                      setState(() => _optionsTab = value.first),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _optionsTab == 0
                          ? [
                              const Text(
                                'These choices affect only the saved video.',
                              ),
                              DropdownButtonFormField<bool>(
                                isExpanded: true,
                                initialValue: _visibility.watchingLayout,
                                decoration: const InputDecoration(
                                  labelText: 'Video layout',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: false,
                                    child: Text('Classic video'),
                                  ),
                                  DropdownMenuItem(
                                    value: true,
                                    child: Text('Watching view'),
                                  ),
                                ],
                                onChanged: (value) => setState(
                                  () => _visibility = VideoVisibility(
                                    watchingLayout: value ?? false,
                                    layers: _visibility.layers,
                                  ),
                                ),
                              ),
                              for (final layer in VideoLayer.values)
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(layer.label),
                                  value: _visibility.shows(layer),
                                  onChanged: (value) => setState(() {
                                    final layers = {..._visibility.layers};
                                    value == true
                                        ? layers.add(layer)
                                        : layers.remove(layer);
                                    _visibility = VideoVisibility(
                                      watchingLayout:
                                          _visibility.watchingLayout,
                                      layers: Set.unmodifiable(layers),
                                    );
                                  }),
                                ),
                            ]
                          : [
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Background music'),
                                value: _includeBgm,
                                onChanged: (v) =>
                                    setState(() => _includeBgm = v ?? false),
                              ),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Sound effects'),
                                value: _includeSfx,
                                onChanged: (v) =>
                                    setState(() => _includeSfx = v ?? false),
                              ),
                            ],
                    ),
                  ),
                ),
                const Text(
                  'Player controls are never shown in the saved replay.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            FilledButton(onPressed: _startExport, child: const Text('START')),
          ],
        );
      case _Phase.exporting:
        return AlertDialog(
          title: const Text('SAVING VIDEO'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 12),
              Text(
                '${(_progress * 100).round()}%',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Elapsed ${_formatElapsed(_elapsed.elapsed)}',
                key: const ValueKey('video-export-elapsed'),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _cancelled = true;
                Navigator.of(context).pop();
              },
              child: const Text('CANCEL'),
            ),
          ],
        );
      case _Phase.saved:
        return AlertDialog(
          title: const Text('VIDEO SAVED'),
          content: Text(widget.saver.savedMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CLOSE'),
            ),
            FilledButton.icon(
              onPressed: () => widget.saver.share(_savedVideo!),
              icon: const Icon(Icons.share),
              label: const Text('SHARE'),
            ),
          ],
        );
      case _Phase.failed:
        return AlertDialog(
          title: const Text('COULD NOT SAVE VIDEO'),
          content: Text(_error ?? 'Unknown error'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CLOSE'),
            ),
          ],
        );
    }
  }

  static String _formatElapsed(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
