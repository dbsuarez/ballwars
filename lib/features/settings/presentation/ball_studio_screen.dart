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
  });
  final AppSettings initial;
  final Future<void> Function(AppSettings settings) onSave;
  @override
  State<BallStudioScreen> createState() => _BallStudioScreenState();
}

class _BallStudioScreenState extends State<BallStudioScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  late BallAppearance _appearance = widget.initial.ballAppearance;
  late bool _glow = widget.initial.ballGlowEnabled;
  late double _glowWidth = widget.initial.ballGlowWidth;
  bool _busy = false, _previewChosen = false;
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
    PowerUpSprites.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
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
        final tab = data['tab'];
        if (tab is int && tab >= 0 && tab < 3) _tabs.index = tab;
      });
    } catch (_) {
      /* A malformed preview preference uses the defaults. */
    }
  }

  void _rememberPreview() {
    _previewChosen = true;
    DevicePrefs.write(
      'ball-studio-preview',
      jsonEncode({
        'radius': _radius,
        'health': _health,
        'expression': _expression?.name,
        'weapon': _weapon?.name,
        'color': _color.toARGB32(),
        'tab': _tabs.index,
      }),
    );
  }

  void _edit(VoidCallback change) {
    setState(() {
      change();
      _message = null;
      _error = null;
    });
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
          '${value.toStringAsFixed(1)}${unit ?? ''}',
          textAlign: TextAlign.right,
        ),
      ),
      Slider(key: key, value: value, min: min, max: max, onChanged: changed),
    ],
  );

  Widget _preview() {
    final ball = SimulationBall(
      config: CustomBall(
        id: 'studio',
        name: 'Preview',
        primaryColor: _color,
        glowColor: Color(_appearance.glowColorValue ?? _color.toARGB32()),
      ),
      position: Offset.zero,
      velocity: const Offset(100, 0),
      radius: _radius,
      lineCount: 0,
    )..life = _health;
    if (_weapon != null) ball.equipWeapon(_weapon!, dualWield: false);
    return SizedBox(
      height: MediaQuery.viewInsetsOf(context).bottom > 0 ? 120 : 220,
      child: CustomPaint(
        key: const ValueKey('ball-studio-preview'),
        size: Size.infinite,
        painter: ArenaPainter(
          state: SimulationState(
            balls: [ball],
            particles: ParticleSystem(),
            floatingTexts: FloatingTextManager(),
            status: MatchStatus.running,
            winnerId: null,
            arenaRadius: 110,
          ),
          arenaRadius: 110,
          rimAngle: 0,
          look: BallLook.faces,
          showBallGlow: _glow,
          ballGlowWidth: _glowWidth,
          ballAppearance: _appearance,
          previewExpression: _expression,
          showHpBars: true,
          showEffects: false,
          arenaTitle: '',
          arenaSubtitle: '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Ball Studio'),
      actions: [
        IconButton(
          tooltip: 'About Ball Studio',
          icon: const Icon(Icons.info_outline),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Ball Studio'),
              content: const Text(
                'The live preview uses the arena renderer. Glow, hands and HP-bar size are shared settings for matches. Enhanced expressions react to aiming, stun, overcharge and health. Choose Faces or Both in Match Setup to see expressions; picture balls use hands when enabled in Match Setup.\n\nPreview color, radius, health, equipment and forced expression are for testing only and are remembered on this device. Save applies the appearance settings. Reset defaults changes this draft until saved.',
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
        onTap: (_) => _rememberPreview(),
        tabs: const [
          Tab(text: 'Body'),
          Tab(text: 'Face & hands'),
          Tab(text: 'HP bar'),
        ],
      ),
    ),
    body: Column(
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
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(
                        key: const ValueKey('studio-glow-color'),
                        icon: Icon(Icons.circle, color: Color(_appearance.glowColorValue ?? _color.toARGB32())),
                        label: Text(_appearance.glowColorValue == null ? 'Ball color' : 'Custom'),
                        onPressed: () async {
                          final chosen = await showColorPicker(context,
                            initialColor: Color(_appearance.glowColorValue ?? _color.toARGB32()),
                            title: 'Glow color');
                          if (chosen != null && mounted) {
                            _edit(() => _appearance = _appearance.copyWith(
                              glowColorValue: chosen.toARGB32(),
                            ));
                          }
                        },
                      )),
                      IconButton(
                        tooltip: 'Use each ball color',
                        onPressed: () => _edit(() => _appearance =
                          _appearance.copyWith(resetGlowColor: true)),
                        icon: const Icon(Icons.restart_alt),
                      ),
                    ]),
                  ),
                  const Divider(),
                  const Text(
                    'Preview only',
                    style: TextStyle(fontWeight: FontWeight.bold),
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
                          DropdownMenuItem(
                            value: kind,
                            child: Text(kind.label),
                          ),
                      ],
                      onChanged: (v) {
                        setState(() => _weapon = v);
                        _rememberPreview();
                      },
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
                        () => _appearance = _appearance.copyWith(handStyle: v),
                      ),
                    ),
                  ),
                  _slider(
                    'Hand size',
                    _appearance.handScale,
                    .5,
                    2,
                    (v) => _edit(
                      () => _appearance = _appearance.copyWith(handScale: v),
                    ),
                    key: const ValueKey('studio-hand-scale'),
                    unit: '×',
                  ),
                  _slider('Eye size', _appearance.eyeScale, .5, 1.5,
                    (v) => _edit(() => _appearance = _appearance.copyWith(eyeScale: v)),
                    key: const ValueKey('studio-eye-size'), unit: '×'),
                  _slider('Mouth position', _appearance.mouthOffset, -.25, .25,
                    (v) => _edit(() => _appearance = _appearance.copyWith(mouthOffset: v)),
                    key: const ValueKey('studio-mouth-position')),
                  const Divider(),
                  const Text(
                    'Preview only',
                    style: TextStyle(fontWeight: FontWeight.bold),
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
                ],
              ),
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _row(
                    'HP-bar size',
                    DropdownButtonFormField<HpBarSize>(
                      key: ValueKey('studio-hp-size-${_appearance.hpBarSize}'),
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
                        () => _appearance = _appearance.copyWith(hpBarSize: v),
                      ),
                    ),
                  ),
                  const Text(
                    'Small preserves the current size. A one-pixel outline keeps the bar visible. Match Setup still controls whether HP bars are shown.',
                  ),
                  const Divider(),
                  const Text(
                    'Preview only',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  _slider('Health', _health, 0, 150, (v) {
                    setState(() => _health = v);
                    _rememberPreview();
                  }, unit: ' HP'),
                ],
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Save failed: $_error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_message != null)
          Padding(padding: const EdgeInsets.all(8), child: Text(_message!)),
      ],
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
                    : () => setState(() {
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
