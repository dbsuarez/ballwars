import '../../../core/theme/game_ui.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../../../core/utils/ball_image_loader.dart';
import '../../custom_groups/data/custom_group_repository.dart';
import '../../ball_management/data/local_ball_repository.dart';
import '../data/ball_appearance_preset_store.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/offline/device_prefs.dart';
import '../../../core/widgets/color_picker_dialog.dart';
import '../../arena_simulation/domain/floating_text.dart';
import '../../arena_simulation/domain/particle_system.dart';
import '../../arena_simulation/domain/power_up.dart';
import '../../arena_simulation/domain/simulation_ball.dart';
import '../../arena_simulation/domain/simulation_state.dart';
import '../../arena_simulation/presentation/arena_painter.dart';
import '../../arena_simulation/presentation/ball_face_expression.dart';
import '../../arena_simulation/presentation/power_up_sprites.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../../match_setup/domain/match_config.dart';
import '../domain/app_settings.dart';

/// Admin-only entry lives in Settings > Appearance. Draft controls use the
/// actual arena painter, and only Save changes the shared game appearance.
class BallStudioScreen extends StatefulWidget {
  const BallStudioScreen({
    super.key,
    required this.initial,
    required this.onSave,
    this.groups,
    this.previewBalls = const [],
  });
  final CustomGroupRepository? groups;
  final List<CustomBall> previewBalls;
  final AppSettings initial;
  final Future<void> Function(AppSettings settings) onSave;
  @override
  State<BallStudioScreen> createState() => _BallStudioScreenState();
}

class _BallStudioScreenState extends State<BallStudioScreen>
    with TickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this);
  late BallAppearance _appearance = widget.initial.ballAppearance;
  late bool _glow = widget.initial.ballGlowEnabled;
  late double _glowWidth = widget.initial.ballGlowWidth;
  bool _busy = false, _previewChosen = false;
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  );
  final _presetStore = BallAppearancePresetStore();
  List<BallAppearancePreset> _presets = [];
  bool _presetsReady = false, _presetBusy = false;
  String? _presetError, _selectedPreset, _ballError;
  List<CustomBall> _balls = [];
  CustomBall? _selectedBall;
  final Map<String, ui.Image?> _images = {};
  BallLook _look = BallLook.faces;
  String _scene = 'Single';
  String? _rememberedBallId;
  final _presetName = TextEditingController();
  int _lastTab = 0;
  String? _error, _message;
  Color _color = const Color(0xff28c5d1);
  double _radius = 42, _health = 70;
  FaceExpression? _expression;
  PowerUpKind? _weapon;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (_tabs.index != _lastTab && !_tabs.indexIsChanging) {
        _lastTab = _tabs.index;
        _rememberPreview();
      }
    });
    _restorePreview();
    _loadPresets();
    _loadBalls();
    _syncClock();
    PowerUpSprites.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock.dispose();
    _presetName.dispose();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _restorePreview() async {
    final raw = await DevicePrefs.read('ball-studio-preview');
    if (raw == null || !mounted || _previewChosen) return;
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return;
      setState(() {
        double bounded(String key, double fallback, double min, double max) {
          final value = data[key];
          return value is num && value.isFinite
              ? value.toDouble().clamp(min, max)
              : fallback;
        }

        _radius = bounded('radius', 42, 18, 52);
        _health = bounded('health', 70, 0, 150);
        _expression = FaceExpression.values
            .where((e) => e.name == data['expression'])
            .firstOrNull;
        _weapon = PowerUpKind.values
            .where((e) => e.name == data['weapon'])
            .firstOrNull;
        if (data['color'] is int) _color = Color(data['color'] as int);
        _look =
            BallLook.values.where((v) => v.name == data['look']).firstOrNull ??
            BallLook.faces;
        _scene = ['Single', 'Phone', 'Six balls'].contains(data['scene'])
            ? data['scene'] as String
            : 'Single';
        _rememberedBallId = data['ball'] is String
            ? data['ball'] as String
            : null;
        _selectedBall = _balls
            .where((b) => b.id == _rememberedBallId)
            .firstOrNull;
        final tab = data['tab'];
        if (tab is int && tab >= 0 && tab < 5) _tabs.index = tab;
      });
      if (_selectedBall != null) _loadImage(_selectedBall!);
      if (_scene == 'Six balls') {
        for (final b in _balls.take(6)) {
          _loadImage(b);
        }
      }
    } catch (_) {
      /* A malformed preview preference uses the defaults. */
    }
  }

  void _rememberPreview() {
    _previewChosen = true;
    _rememberedBallId = _selectedBall?.id;
    DevicePrefs.write(
      'ball-studio-preview',
      jsonEncode({
        'radius': _radius,
        'health': _health,
        'expression': _expression?.name,
        'weapon': _weapon?.name,
        'color': _color.toARGB32(),
        'tab': _tabs.index,
        'look': _look.name,
        'scene': _scene,
        'ball': _selectedBall?.id,
      }),
    );
  }

  void _edit(VoidCallback change) {
    setState(() {
      change();
      _message = null;
      _error = null;
    });
    _syncClock();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await widget.onSave(
        widget.initial.copyWith(
          ballAppearance: _appearance.validated(),
          ballGlowEnabled: _glow,
          ballGlowWidth: _glowWidth,
        ),
      );
      if (mounted) setState(() => _message = 'Ball appearance saved.');
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error'.replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _row(String label, Widget control) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(flex: 4, child: Text(label)),
        const SizedBox(width: 12),
        Expanded(flex: 5, child: control),
      ],
    ),
  );

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> changed, {
    Key? key,
    String? unit,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _row(
        label,
        Text(
          '${value.toStringAsFixed(max <= 1 ? 2 : 1)}${unit ?? ''}',
          textAlign: TextAlign.right,
        ),
      ),
      Slider(key: key, value: value, min: min, max: max, onChanged: changed),
    ],
  );

  void _syncClock() {
    if (_appearance.blinkInterval > 0) {
      if (!_clock.isAnimating) _clock.repeat();
    } else {
      _clock.stop();
    }
  }

  Future<void> _loadBalls() async {
    try {
      final groups = await widget.groups?.myGroups() ?? [];
      final byId = <String, CustomBall>{
        for (final b in [
          ...widget.previewBalls,
          ...groups.expand((g) => g.balls),
          ...LocalBallRepository.presets,
        ])
          b.id: b,
      };
      if (!mounted) return;
      setState(() {
        _balls = byId.values.toList();
        _selectedBall = _balls
            .where((b) => b.id == _rememberedBallId)
            .firstOrNull;
        _ballError = null;
      });
      if (_scene == 'Six balls') {
        for (final b in _balls.take(6)) {
          _loadImage(b);
        }
      }
      if (_selectedBall != null) _loadImage(_selectedBall!);
    } catch (e) {
      if (mounted) {
        setState(() => _ballError = 'Could not load saved balls: $e');
      }
    }
  }

  Future<void> _loadImage(CustomBall ball) async {
    final image = await BallImageLoader.load(ball);
    if (!mounted) return;
    setState(() {
      _images[ball.id] = image;
    });
    if (image == null &&
        (_selectedBall?.id == ball.id || _scene == 'Six balls') &&
        (ball.imageBytes != null || ball.imageUrl != null)) {
      setState(
        () =>
            _ballError = 'Picture unavailable. Showing the ball color instead.',
      );
    }
  }

  Future<void> _loadPresets() async {
    try {
      final values = await _presetStore.load();
      if (mounted) {
        setState(() {
          _presets = values;
          _presetsReady = true;
          _presetError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _presetsReady = false;
          _presetError = 'Could not read presets: $e';
        });
      }
    }
  }

  Future<void> _writePreset({bool delete = false}) async {
    final name = _presetName.text.trim();
    if (!delete && (name.isEmpty || name.length > 40)) {
      setState(() => _presetError = 'Enter a name of 1 to 40 characters.');
      return;
    }
    final existing = _presets
        .where((p) => p.name.toLowerCase() == name.toLowerCase())
        .firstOrNull;
    if (!delete && existing != null) {
      final replace = await showGameDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Replace ${existing.name}?'),
          content: const Text(
            'Replace this device preset with the current draft?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }
    setState(() {
      _presetBusy = true;
      _presetError = null;
    });
    final next = _presets
        .where(
          (p) =>
              p.name.toLowerCase() !=
              (delete ? _selectedPreset : name)?.toLowerCase(),
        )
        .toList();
    if (!delete) {
      next.add(
        BallAppearancePreset(
          name: name,
          appearance: _appearance.validated(),
          glowEnabled: _glow,
          glowWidth: _glowWidth,
        ),
      );
    }
    try {
      await _presetStore.save(next);
      if (mounted) {
        setState(() {
          _presets = next;
          _selectedPreset = delete ? null : name;
          if (delete) _presetName.clear();
          _message = delete
              ? 'Preset deleted from this device.'
              : 'Preset saved on this device.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _presetError = 'Preset save failed: $e');
    } finally {
      if (mounted) setState(() => _presetBusy = false);
    }
  }

  Widget _preview() => AnimatedBuilder(
    animation: _clock,
    builder: (context, _) {
      final count = _scene == 'Six balls' ? 6 : 1;
      final sample =
          _selectedBall ??
          CustomBall(
            id: 'studio',
            name: 'Preview',
            primaryColor: _color,
            glowColor: _color,
          );
      final candidates = [sample, ..._balls.where((b) => b.id != sample.id)];
      final balls = List.generate(count, (i) {
        final config = i < candidates.length
            ? candidates[i]
            : CustomBall(
                id: 'studio-$i',
                name: 'Preview ${i + 1}',
                primaryColor: Colors.primaries[i % Colors.primaries.length],
                glowColor: _color,
              );
        final angle = i * math.pi / 3 - math.pi / 2;
        final ball =
            SimulationBall(
                config: config,
                position: count == 1
                    ? Offset.zero
                    : Offset(math.cos(angle), math.sin(angle)) * 67,
                velocity: const Offset(100, 0),
                radius: count == 1 ? _radius : math.min(_radius, 22),
                lineCount: 0,
              )
              ..life = _health
              ..cachedUiImage = _images[config.id];
        if (_weapon != null) ball.equipWeapon(_weapon!, dualWield: false);
        return ball;
      });
      final paint = CustomPaint(
        key: const ValueKey('ball-studio-preview'),
        size: Size.infinite,
        painter: ArenaPainter(
          state: SimulationState(
            balls: balls,
            particles: ParticleSystem(),
            floatingTexts: FloatingTextManager(),
            status: MatchStatus.running,
            winnerId: null,
            step: (_clock.value * 3600).floor(),
            arenaRadius: 110,
          ),
          arenaRadius: 110,
          rimAngle: 0,
          look: _look,
          handsOnPictures: true,
          showBallGlow: _glow,
          ballGlowWidth: _glowWidth,
          ballAppearance: _appearance,
          previewExpression: _expression,
          showHpBars: true,
          showBallNames: _scene != 'Single',
          showEffects: false,
          arenaTitle: '',
          arenaSubtitle: '',
        ),
      );
      final short = MediaQuery.viewInsetsOf(context).bottom > 0;
      if (_scene != 'Phone') {
        return SizedBox(height: short ? 120 : 220, child: paint);
      }
      return SizedBox(
        height: short ? 120 : 250,
        child: Center(
          child: AspectRatio(
            aspectRatio: 390 / 760,
            child: Container(
              key: const ValueKey('studio-phone-frame'),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  const Text('Phone preview', style: TextStyle(fontSize: 10)),
                  AspectRatio(aspectRatio: 1, child: paint),
                  const Spacer(),
                  const Text(
                    'HP above / name below',
                    style: TextStyle(fontSize: 9),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _previewControls() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text('Preview only - these choices do not change match settings.'),
      _row(
        'View',
        DropdownButtonFormField<String>(
          key: ValueKey('studio-scene-$_scene'),
          initialValue: _scene,
          isExpanded: true,
          items: [
            for (final s in ['Single', 'Phone', 'Six balls'])
              DropdownMenuItem(value: s, child: Text(s)),
          ],
          onChanged: (v) {
            setState(() => _scene = v!);
            _rememberPreview();
            if (_scene == 'Six balls') {
              for (final b in _balls.take(6)) {
                _loadImage(b);
              }
            }
          },
        ),
      ),
      _row(
        'Look',
        DropdownButtonFormField<BallLook>(
          key: ValueKey('studio-look-$_look'),
          initialValue: _look,
          isExpanded: true,
          items: [
            for (final look in BallLook.values)
              DropdownMenuItem(
                value: look,
                child: Text(
                  look.name == 'pictures'
                      ? 'Picture'
                      : look.name == 'faces'
                      ? 'Face'
                      : 'Both',
                ),
              ),
          ],
          onChanged: (v) {
            setState(() => _look = v!);
            _rememberPreview();
          },
        ),
      ),
      _row(
        'Saved ball',
        DropdownButtonFormField<String>(
          key: ValueKey('studio-ball-${_selectedBall?.id}'),
          initialValue: _selectedBall?.id,
          isExpanded: true,
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('Test color'),
            ),
            for (final b in _balls)
              DropdownMenuItem(
                value: b.id,
                child: Text(b.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (id) {
            setState(() {
              _selectedBall = _balls.where((b) => b.id == id).firstOrNull;
              _ballError = null;
            });
            _rememberPreview();
            if (_selectedBall != null) _loadImage(_selectedBall!);
          },
        ),
      ),
      if (_ballError != null) ...[
        Text(_ballError!),
        TextButton(
          onPressed: _loadBalls,
          child: const Text('Retry loading balls'),
        ),
      ],
      const Text(
        'Single previews the chosen size. Six balls uses match-like spacing and smaller balls to check visual density.',
      ),
      _row(
        'Ball color',
        OutlinedButton.icon(
          icon: Icon(Icons.circle, color: _color),
          label: const Text('Choose'),
          onPressed: () async {
            final value = await showColorPicker(
              context,
              initialColor: _color,
              title: 'Preview ball color',
            );
            if (value != null && mounted) {
              setState(() => _color = value);
              _rememberPreview();
            }
          },
        ),
      ),
      _slider('Ball radius', _radius, 18, 52, (v) {
        setState(() => _radius = v);
        _rememberPreview();
      }),
      _row(
        'Held item',
        DropdownButtonFormField<PowerUpKind?>(
          key: ValueKey('studio-item-$_weapon'),
          initialValue: _weapon,
          isExpanded: true,
          items: [
            const DropdownMenuItem<PowerUpKind?>(
              value: null,
              child: Text('None'),
            ),
            for (final kind in [
              PowerUpKind.pistol,
              PowerUpKind.sword,
              PowerUpKind.shield,
              PowerUpKind.bow,
            ])
              DropdownMenuItem(value: kind, child: Text(kind.label)),
          ],
          onChanged: (v) {
            setState(() => _weapon = v);
            _rememberPreview();
          },
        ),
      ),
      _row(
        'Expression',
        DropdownButtonFormField<FaceExpression?>(
          key: ValueKey('studio-expression-$_expression'),
          initialValue: _expression,
          isExpanded: true,
          items: [
            const DropdownMenuItem<FaceExpression?>(
              value: null,
              child: Text('Automatic'),
            ),
            for (final expression in FaceExpression.values)
              DropdownMenuItem(
                value: expression,
                child: Text(expression.label),
              ),
          ],
          onChanged: (v) {
            setState(() => _expression = v);
            _rememberPreview();
          },
        ),
      ),
      const Text(
        'Choose an expression to test it even when enhanced expressions are off.',
      ),
      _slider('Health', _health, 0, 150, (v) {
        setState(() => _health = v);
        _rememberPreview();
      }, unit: ' HP'),
    ],
  );

  Widget _presetControls() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text(
        'Presets are saved on this device. Apply changes the draft; Save below publishes the appearance for matches.',
      ),
      if (!_presetsReady && _presetError == null)
        const LinearProgressIndicator(),
      if (_presetsReady) ...[
        _row(
          'Saved preset',
          DropdownButtonFormField<String>(
            key: ValueKey('studio-preset-$_selectedPreset'),
            initialValue: _selectedPreset,
            isExpanded: true,
            hint: const Text('Choose'),
            items: [
              for (final p in _presets)
                DropdownMenuItem(value: p.name, child: Text(p.name)),
            ],
            onChanged: _presetBusy
                ? null
                : (v) => setState(() {
                    _selectedPreset = v;
                    _presetName.text = v ?? '';
                  }),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _selectedPreset == null || _presetBusy
                    ? null
                    : () {
                        final preset = _presets.firstWhere(
                          (p) => p.name == _selectedPreset,
                        );
                        _edit(() {
                          _appearance = preset.appearance;
                          _glow = preset.glowEnabled;
                          _glowWidth = preset.glowWidth;
                        });
                      },
                icon: const Icon(Icons.check),
                label: const Text('Apply to draft'),
              ),
            ),
            IconButton(
              tooltip: 'Delete selected preset',
              onPressed: _selectedPreset == null || _presetBusy
                  ? null
                  : () async {
                      final yes = await showGameDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete preset?'),
                          content: Text(
                            'Delete $_selectedPreset from this device?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (yes == true && mounted) _writePreset(delete: true);
                    },
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _row(
          'Preset name',
          TextField(
            key: const ValueKey('studio-preset-name'),
            controller: _presetName,
            maxLength: 40,
            decoration: const InputDecoration(
              hintText: 'e.g. Big eyes, soft glow',
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: _presetBusy ? null : () => _writePreset(),
          icon: const Icon(Icons.bookmark_add_outlined),
          label: Text(_presetBusy ? 'Saving...' : 'Save draft as preset'),
        ),
      ],
      if (_presetError != null) ...[
        Text(
          _presetError!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        if (!_presetsReady)
          TextButton(
            onPressed: _loadPresets,
            child: const Text('Retry loading presets'),
          ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) => GameWorkbench(builder: _buildWorkbench);

  Widget _buildWorkbench(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Ball Studio'),
      actions: [
        IconButton(
          tooltip: 'About Ball Studio',
          icon: const Icon(Icons.info_outline),
          onPressed: () => showGameDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Ball Studio'),
              content: const Text(
                'The live preview uses the arena renderer. Glow, face controls, hands and HP-bar size are shared settings for matches. Enhanced expressions react to aiming, stun, overcharge and health. Choose Faces or Both in Match Setup to see expressions; picture balls use hands when enabled in Match Setup.\n\nPreview look, scene, saved ball, color, radius, health, equipment and forced expression are for testing only and are remembered on this device. Save applies the appearance settings. Reset defaults changes this draft until saved.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ],
      bottom: TabBar(
        controller: _tabs,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        onTap: (_) => _rememberPreview(),
        tabs: const [
          Tab(text: 'Body'),
          Tab(text: 'Face & hands'),
          Tab(text: 'HP bar'),
          Tab(text: 'Preview'),
          Tab(text: 'Presets'),
        ],
      ),
    ),
    body: LayoutBuilder(
      builder: (context, bounds) => SingleChildScrollView(
        child: SizedBox(
          height: math.max(440, bounds.maxHeight),
          child: Column(
            children: [
              _preview(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Live arena preview · preview choices do not change ball stats',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Outer glow'),
                          value: _glow,
                          onChanged: (v) => _edit(() => _glow = v),
                        ),
                        _slider(
                          'Glow width',
                          _glowWidth,
                          1,
                          12,
                          (v) => _edit(() => _glowWidth = v),
                          key: const ValueKey('studio-glow-width'),
                        ),
                        _row(
                          'Glow color',
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  key: const ValueKey('studio-glow-color'),
                                  icon: Icon(
                                    Icons.circle,
                                    color: Color(
                                      _appearance.glowColorValue ??
                                          _color.toARGB32(),
                                    ),
                                  ),
                                  label: Text(
                                    _appearance.glowColorValue == null
                                        ? 'Ball color'
                                        : 'Custom',
                                  ),
                                  onPressed: () async {
                                    final chosen = await showColorPicker(
                                      context,
                                      initialColor: Color(
                                        _appearance.glowColorValue ??
                                            _color.toARGB32(),
                                      ),
                                      title: 'Glow color',
                                    );
                                    if (chosen != null && mounted) {
                                      _edit(
                                        () =>
                                            _appearance = _appearance.copyWith(
                                              glowColorValue: chosen.toARGB32(),
                                            ),
                                      );
                                    }
                                  },
                                ),
                              ),
                              IconButton(
                                tooltip: 'Use each ball color',
                                onPressed: () => _edit(
                                  () => _appearance = _appearance.copyWith(
                                    resetGlowColor: true,
                                  ),
                                ),
                                icon: const Icon(Icons.restart_alt),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        SwitchListTile(
                          key: const ValueKey('studio-expressions'),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Enhanced expressions'),
                          subtitle: const Text(
                            'React to aiming, stun, overcharge and health.',
                          ),
                          value: _appearance.expressiveFaces,
                          onChanged: (v) => _edit(
                            () => _appearance = _appearance.copyWith(
                              expressiveFaces: v,
                            ),
                          ),
                        ),
                        _row(
                          'Hand style',
                          DropdownButtonFormField<BallHandStyle>(
                            key: ValueKey(
                              'studio-hand-style-${_appearance.handStyle}',
                            ),
                            initialValue: _appearance.handStyle,
                            isExpanded: true,
                            items: [
                              for (final style in BallHandStyle.values)
                                DropdownMenuItem(
                                  value: style,
                                  child: Text(style.label),
                                ),
                            ],
                            onChanged: (v) => _edit(
                              () => _appearance = _appearance.copyWith(
                                handStyle: v,
                              ),
                            ),
                          ),
                        ),
                        _slider(
                          'Hand size',
                          _appearance.handScale,
                          .5,
                          2,
                          (v) => _edit(
                            () => _appearance = _appearance.copyWith(
                              handScale: v,
                            ),
                          ),
                          key: const ValueKey('studio-hand-scale'),
                          unit: '×',
                        ),
                        _slider(
                          'Eye size',
                          _appearance.eyeScale,
                          .5,
                          1.5,
                          (v) => _edit(
                            () =>
                                _appearance = _appearance.copyWith(eyeScale: v),
                          ),
                          key: const ValueKey('studio-eye-size'),
                          unit: '×',
                        ),
                        _slider(
                          'Mouth position',
                          _appearance.mouthOffset,
                          -.25,
                          .25,
                          (v) => _edit(
                            () => _appearance = _appearance.copyWith(
                              mouthOffset: v,
                            ),
                          ),
                          key: const ValueKey('studio-mouth-position'),
                        ),
                        _slider(
                          'Mouth size',
                          _appearance.mouthScale,
                          .5,
                          1.5,
                          (v) => _edit(
                            () => _appearance = _appearance.copyWith(
                              mouthScale: v,
                            ),
                          ),
                          key: const ValueKey('studio-mouth-size'),
                        ),
                        _slider(
                          'Pupil tracking',
                          _appearance.pupilFollow,
                          0,
                          2,
                          (v) => _edit(
                            () => _appearance = _appearance.copyWith(
                              pupilFollow: v,
                            ),
                          ),
                          key: const ValueKey('studio-pupil-follow'),
                        ),
                        const Text(
                          '0 centers the pupils; 1 follows opponents normally; 2 emphasizes the look. Choose Six balls in Preview to see tracking.',
                        ),
                        SwitchListTile(
                          title: const Text('Blink'),
                          value: _appearance.blinkInterval > 0,
                          onChanged: (v) => _edit(
                            () => _appearance = _appearance.copyWith(
                              blinkInterval: v ? 4 : 0,
                            ),
                          ),
                        ),
                        if (_appearance.blinkInterval > 0) ...[
                          _slider(
                            'Blink every',
                            _appearance.blinkInterval,
                            1,
                            10,
                            (v) => _edit(
                              () => _appearance = _appearance.copyWith(
                                blinkInterval: v,
                              ),
                            ),
                            unit: ' s',
                          ),
                          _slider(
                            'Blink duration',
                            _appearance.blinkDuration,
                            .06,
                            .4,
                            (v) => _edit(
                              () => _appearance = _appearance.copyWith(
                                blinkDuration: v,
                              ),
                            ),
                            unit: ' s',
                          ),
                        ],
                      ],
                    ),
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _row(
                          'HP-bar size',
                          DropdownButtonFormField<HpBarSize>(
                            key: ValueKey(
                              'studio-hp-size-${_appearance.hpBarSize}',
                            ),
                            initialValue: _appearance.hpBarSize,
                            isExpanded: true,
                            items: [
                              for (final size in HpBarSize.values)
                                DropdownMenuItem(
                                  value: size,
                                  child: Text(size.label),
                                ),
                            ],
                            onChanged: (v) => _edit(
                              () => _appearance = _appearance.copyWith(
                                hpBarSize: v,
                              ),
                            ),
                          ),
                        ),
                        const Text(
                          'Small preserves the current size. A one-pixel outline keeps the bar visible. Match Setup still controls whether HP bars are shown.',
                        ),
                      ],
                    ),
                    _previewControls(),
                    _presetControls(),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Save failed: $_error',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_message!),
                ),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _edit(() {
                        _appearance = BallAppearance.defaults;
                        _glow = true;
                        _glowWidth = 4;
                        _message = null;
                        _error = null;
                      }),
                icon: const Icon(Icons.restore),
                label: const Text('Reset defaults'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('save-ball-studio'),
                onPressed: _busy ? null : _save,
                icon: Icon(_busy ? Icons.hourglass_top : Icons.save_outlined),
                label: Text(_busy ? 'Saving…' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
