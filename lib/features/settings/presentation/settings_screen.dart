import 'package:flutter/material.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/theme/app_theme.dart';
import '../../custom_groups/data/custom_group_repository.dart';
import '../../custom_groups/presentation/my_groups_screen.dart';
import '../../arena_simulation/domain/power_up_config.dart';
import '../../skills/presentation/skill_management_screen.dart';
import '../domain/app_settings.dart';
import 'power_up_tuning_screen.dart';
import 'power_up_rarity_screen.dart';
import 'app_settings_scope.dart';
import 'finisher_gallery_screen.dart';
import 'power_up_test_screen.dart';

/// Settings. Players see only the admin sign-in; once the admin signs in
/// (email + password, listed in the `admins` table) they can change the
/// headline and theme for everyone and manage every user's groups.
class SettingsScreen extends StatefulWidget {
  final CustomGroupRepository? customGroups;

  /// [customGroups] through the admin's session: edits to anyone's groups.
  final CustomGroupRepository? adminGroups;

  const SettingsScreen({super.key, this.customGroups, this.adminGroups});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _settingsTab = 0;

  Future<void> _pickBloodColor(AppSettings settings) async {
    final controller = TextEditingController(
      text: (settings.bloodColor.toARGB32() & 0xFFFFFF)
          .toRadixString(16)
          .padLeft(6, '0')
          .toUpperCase(),
    );
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom blood color'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 6,
          decoration: const InputDecoration(
            prefixText: '#',
            hintText: '22CC66',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final raw = controller.text.trim().replaceFirst('#', '');
              if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(raw)) return;
              Navigator.pop(
                context,
                Color(0xFF000000 | int.parse(raw, radix: 16)),
              );
            },
            child: const Text('Use color'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (color != null && mounted) {
      await _save(
        settings.copyWith(bloodColor: color),
        done: 'Blood color saved.',
      );
    }
  }

  final TextEditingController _headline = TextEditingController();
  final TextEditingController _watermark = TextEditingController();
  final TextEditingController _arenaTitle = TextEditingController();
  final TextEditingController _arenaSubtitle = TextEditingController();
  bool? _isAdmin;
  // Slow-motion choices before they are saved.
  int? _slowMotionLines;
  bool? _slowBeforeWin;
  double? _slowSeconds;
  double? _minimumArenaScale;
  bool _busy = false;
  String? _message;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isAdmin == null) {
      _headline.text = AppSettingsScope.of(context).headline;
      _watermark.text = AppSettingsScope.of(context).watermarkText;
      _arenaTitle.text = AppSettingsScope.of(context).arenaTitle;
      _arenaSubtitle.text = AppSettingsScope.of(context).arenaSubtitle;
      _checkAdmin();
    }
  }

  @override
  void dispose() {
    _headline.dispose();
    _watermark.dispose();
    _arenaTitle.dispose();
    _arenaSubtitle.dispose();
    GameAudio.instance.stopPreview();
    super.dispose();
  }

  AppSettingsScope? get _scope => AppSettingsScope.maybeScope(context);

  Future<void> _checkAdmin() async {
    final auth = _scope?.adminAuth;
    final admin = auth == null ? false : await auth.isAdmin();
    if (mounted) setState(() => _isAdmin = admin);
  }

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      if (mounted && done != null) setState(() => _message = done);
    } catch (e) {
      if (mounted) {
        final message = '$e'.replaceFirst('Bad state: ', '');
        setState(() => _message = message);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Save failed: $message'),
              backgroundColor: Colors.red.shade800,
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() async {
    final result = await showDialog<(String, String, bool)>(
      context: context,
      builder: (_) => const _SignInDialog(),
    );
    if (result == null) return;
    await _run(() async {
      await _scope!.adminAuth!.signIn(
        result.$1,
        result.$2,
        rememberMe: result.$3,
      );
      if (mounted) setState(() => _isAdmin = true);
    });
  }

  Future<void> _signOut() => _run(() async {
    await _scope!.adminAuth!.signOut();
    if (mounted) setState(() => _isAdmin = false);
  });

  Future<void> _cleanUpImages() async {
    var removed = 0;
    await _run(
      () async => removed = await widget.adminGroups!.cleanUpUnusedImages(),
    );
    if (mounted && _message == null) {
      setState(
        () => _message = removed == 0
            ? 'No unused images.'
            : 'Removed $removed unused images.',
      );
    }
  }

  void _togglePreview(MusicTrack track) {
    final audio = GameAudio.instance;
    if (audio.isPreviewing(track)) {
      audio.stopPreview();
    } else {
      audio.preview(
        track,
        onDone: () {
          if (mounted) setState(() {});
        },
      );
    }
    setState(() {});
  }

  /// Applies [settings] right away (live preview) and saves it for everyone.
  Future<void> _save(AppSettings settings, {String? done}) {
    final scope = _scope!;
    final previous = scope.notifier!.value;
    scope.notifier!.value = settings;
    return _run(() async {
      try {
        await scope.repository!.save(settings);
      } catch (_) {
        scope.notifier!.value = previous;
        rethrow;
      }
    }, done: done);
  }

  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    final settings = AppSettingsScope.of(context);
    final hasBackend = _scope?.adminAuth != null && _scope?.repository != null;

    // The whole page (header too) is as wide as Home's column on big
    // screens, so switching between them feels even.
    return ColoredBox(
      color: c.background,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: DefaultTabController(
            length: 4,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Settings'),
                bottom: _isAdmin == true
                    ? PreferredSize(
                        preferredSize: const Size.fromHeight(50),
                        child: Column(
                          children: [
                            if (_busy)
                              const LinearProgressIndicator(minHeight: 2),
                            TabBar(
                              onTap: (index) =>
                                  setState(() => _settingsTab = index),
                              tabs: const [
                                Tab(text: 'General'),
                                Tab(text: 'Gameplay'),
                                Tab(text: 'Appearance'),
                                Tab(text: 'Audio'),
                              ],
                            ),
                          ],
                        ),
                      )
                    : _busy
                    ? const PreferredSize(
                        preferredSize: Size.fromHeight(2),
                        child: LinearProgressIndicator(),
                      )
                    : null,
              ),
              body: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      if (_message != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            _message!,
                            style: AppText.ui(
                              13,
                              FontWeight.w600,
                              color: c.muted,
                            ),
                          ),
                        ),
                      if (!hasBackend)
                        Text(
                          'Settings need a connection to the Ball Wars server.',
                          style: AppText.ui(
                            14,
                            FontWeight.w500,
                            color: c.muted,
                          ),
                        )
                      else if (_isAdmin == null)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_isAdmin == false)
                        _Section(
                          title: 'ADMIN',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'The headline, theme and match music are set by the admin for everyone.',
                                style: AppText.ui(
                                  14,
                                  FontWeight.w500,
                                  color: c.muted,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton(
                                onPressed: _busy ? null : _signIn,
                                child: const Text('Admin sign-in'),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        if (_settingsTab == 0)
                          _Section(
                            title: 'HEADLINE',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: _headline,
                                  maxLength: 30,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  decoration: const InputDecoration(
                                    hintText: AppSettings.defaultHeadline,
                                  ),
                                ),
                                FilledButton(
                                  onPressed:
                                      _busy || _headline.text.trim().isEmpty
                                      ? null
                                      : () => _save(
                                          settings.copyWith(
                                            headline: _headline.text.trim(),
                                          ),
                                          done: 'Headline saved for everyone.',
                                        ),
                                  child: const Text('Save headline'),
                                ),
                              ],
                            ),
                          ),
                        if (_settingsTab == 2)
                          _Section(
                            title: 'ARENA',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Arena decoration',
                                  style: AppText.ui(
                                    14,
                                    FontWeight.w600,
                                    color: c.text,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Changes the floor inside the arena without changing its size or physics.',
                                  style: AppText.ui(
                                    13,
                                    FontWeight.w500,
                                    color: c.muted,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    for (final decoration
                                        in ArenaDecoration.values)
                                      ChoiceChip(
                                        key: ValueKey(
                                          'arena-decoration-${decoration.name}',
                                        ),
                                        avatar: CircleAvatar(
                                          backgroundColor: switch (decoration) {
                                            ArenaDecoration.defaultArena =>
                                              const Color(0xFF181A20),
                                            ArenaDecoration.space =>
                                              const Color(0xFF18245A),
                                            ArenaDecoration.desert =>
                                              const Color(0xFFC88746),
                                            ArenaDecoration.wilderness =>
                                              const Color(0xFF315B37),
                                            ArenaDecoration.neonGrid =>
                                              const Color(0xFF00B8D4),
                                            ArenaDecoration.chaotic =>
                                              const Color(0xFFFF4FD8),
                                          },
                                        ),
                                        label: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(decoration.label),
                                            Text(
                                              switch (decoration) {
                                                ArenaDecoration.defaultArena =>
                                                  'Spike Wall',
                                                ArenaDecoration.space =>
                                                  'Gravity Well',
                                                ArenaDecoration.desert =>
                                                  'Quicksand',
                                                ArenaDecoration.wilderness =>
                                                  'Vine Snare',
                                                ArenaDecoration.neonGrid =>
                                                  'Laser Gate',
                                                ArenaDecoration.chaotic =>
                                                  'All arena traps',
                                              },
                                              style: const TextStyle(
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                        selected:
                                            settings.arenaDecoration ==
                                            decoration,
                                        onSelected: _busy
                                            ? null
                                            : (_) => _save(
                                                settings.copyWith(
                                                  arenaDecoration: decoration,
                                                ),
                                                done:
                                                    '${decoration.label} arena saved.',
                                              ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        if (_settingsTab == 2)
                          _Section(
                            title: 'THEME',
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (final preset in AppPalettes.all)
                                  _ThemeSwatch(
                                    preset: preset,
                                    selected: preset.id == settings.themeId,
                                    onTap: _busy
                                        ? null
                                        : () => _save(
                                            settings.copyWith(
                                              themeId: preset.id,
                                            ),
                                            done: 'Theme set for everyone.',
                                          ),
                                  ),
                              ],
                            ),
                          ),
                        if (_settingsTab == 3)
                          _Section(
                            title: 'MUSIC',
                            child: DefaultTabController(
                              length: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const TabBar(
                                    tabs: [
                                      Tab(text: 'Match music'),
                                      Tab(text: 'Home music'),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 350,
                                    child: TabBarView(
                                      children: [
                                        ListView(
                                          key: const PageStorageKey(
                                            'match-music-tab',
                                          ),
                                          padding: EdgeInsets.zero,
                                          children: [
                                            for (final track in MusicTrack.all)
                                              _TrackRow(
                                                track: track,
                                                selected:
                                                    track.id ==
                                                    settings.musicId,
                                                playing: GameAudio.instance
                                                    .isPreviewing(track),
                                                onPlay: () =>
                                                    _togglePreview(track),
                                                onSelect:
                                                    _busy ||
                                                        track.id ==
                                                            settings.musicId
                                                    ? null
                                                    : () => _save(
                                                        settings.copyWith(
                                                          musicId: track.id,
                                                        ),
                                                        done:
                                                            '"${track.name}" is now the match music for everyone.',
                                                      ),
                                              ),
                                          ],
                                        ),
                                        ListView(
                                          key: const PageStorageKey(
                                            'home-music-tab',
                                          ),
                                          padding: EdgeInsets.zero,
                                          children: [
                                            for (final track in MusicTrack.menu)
                                              _TrackRow(
                                                track: track,
                                                selected:
                                                    track.id ==
                                                    settings.menuMusicId,
                                                playing: GameAudio.instance
                                                    .isPreviewing(track),
                                                onPlay: () =>
                                                    _togglePreview(track),
                                                onSelect:
                                                    _busy ||
                                                        track.id ==
                                                            settings.menuMusicId
                                                    ? null
                                                    : () => _save(
                                                        settings.copyWith(
                                                          menuMusicId: track.id,
                                                        ),
                                                        done:
                                                            '"${track.name}" is now the Home music for everyone.',
                                                      ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (_settingsTab == 0)
                          _Section(
                            title: 'ARENA',
                            child: Builder(
                              builder: (context) {
                                final scale =
                                    _minimumArenaScale ??
                                    settings.minimumArenaScale;
                                final percent = (scale * 100).round();
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Minimum shrinking-arena size: $percent%',
                                      key: const ValueKey(
                                        'minimum-arena-scale-label',
                                      ),
                                      style: AppText.ui(
                                        14,
                                        FontWeight.w600,
                                        color: c.text,
                                      ),
                                    ),
                                    Slider(
                                      key: const ValueKey(
                                        'minimum-arena-scale-slider',
                                      ),
                                      value: scale,
                                      min: 0.40,
                                      max: 0.90,
                                      divisions: 10,
                                      label: '$percent%',
                                      onChanged: _busy
                                          ? null
                                          : (value) => setState(
                                              () => _minimumArenaScale = value,
                                            ),
                                    ),
                                    Text(
                                      'The arena starts at 100% and stops shrinking here. Default 60%.',
                                      style: AppText.ui(
                                        12,
                                        FontWeight.w500,
                                        color: c.muted,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    OutlinedButton(
                                      onPressed:
                                          _busy ||
                                              scale ==
                                                  settings.minimumArenaScale
                                          ? null
                                          : () => _save(
                                              settings.copyWith(
                                                minimumArenaScale: scale,
                                              ),
                                              done:
                                                  'Minimum arena size saved for everyone.',
                                            ),
                                      child: const Text('Save arena size'),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        if (_settingsTab == 0)
                          _Section(
                            title: 'SLOW MOTION',
                            child: Builder(
                              builder: (context) {
                                final beforeWin =
                                    _slowBeforeWin ??
                                    settings.slowMotionBeforeWinSeconds != null;
                                final lines =
                                    _slowMotionLines ??
                                    settings.slowMotionLines;
                                final seconds =
                                    _slowSeconds ??
                                    settings.slowMotionBeforeWinSeconds ??
                                    AppSettings
                                        .defaultSlowMotionBeforeWinSeconds;
                                final changed = beforeWin
                                    ? settings.slowMotionBeforeWinSeconds !=
                                          seconds
                                    : settings.slowMotionBeforeWinSeconds !=
                                              null ||
                                          settings.slowMotionLines != lines;
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SegmentedButton<bool>(
                                      segments: const [
                                        ButtonSegment(
                                          value: false,
                                          label: Text('By lines'),
                                        ),
                                        ButtonSegment(
                                          value: true,
                                          label: Text('Before the win'),
                                        ),
                                      ],
                                      selected: {beforeWin},
                                      onSelectionChanged: _busy
                                          ? null
                                          : (v) => setState(
                                              () => _slowBeforeWin = v.first,
                                            ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      beforeWin
                                          ? 'Starts ${seconds.toStringAsFixed(1)} s before the winning cut.'
                                          : lines == 0
                                          ? 'Off: matches never slow down.'
                                          : 'Starts when one of the last two balls is down to $lines lines or fewer for good.',
                                      style: AppText.ui(
                                        14,
                                        FontWeight.w600,
                                        color: c.text,
                                      ),
                                    ),
                                    if (beforeWin)
                                      Slider(
                                        key: const ValueKey(
                                          'slow-motion-slider',
                                        ),
                                        value: seconds,
                                        min: 0.5,
                                        max: 5,
                                        divisions: 9,
                                        label:
                                            '${seconds.toStringAsFixed(1)} s',
                                        onChanged: _busy
                                            ? null
                                            : (v) => setState(
                                                () => _slowSeconds = v,
                                              ),
                                      )
                                    else
                                      Slider(
                                        key: const ValueKey(
                                          'slow-motion-slider',
                                        ),
                                        value: lines.toDouble(),
                                        min: 0,
                                        max: 60,
                                        divisions: 60,
                                        label: lines == 0 ? 'Off' : '$lines',
                                        onChanged: _busy
                                            ? null
                                            : (v) => setState(
                                                () => _slowMotionLines = v
                                                    .round(),
                                              ),
                                      ),
                                    Text(
                                      beforeWin
                                          ? 'Game time; slow motion plays it 4x slower. The app plays each match ahead to know the moment.'
                                          : 'Default ${AppSettings.defaultSlowMotionLines}. Each ball starts with about 90 lines. '
                                                "A ball that will recover doesn't trigger it.",
                                      style: AppText.ui(
                                        12,
                                        FontWeight.w500,
                                        color: c.muted,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    OutlinedButton(
                                      onPressed: _busy || !changed
                                          ? null
                                          : () => _save(
                                              beforeWin
                                                  ? settings.copyWith(
                                                      slowMotionBeforeWinSeconds:
                                                          () => seconds,
                                                    )
                                                  : settings.copyWith(
                                                      slowMotionLines: lines,
                                                      slowMotionBeforeWinSeconds:
                                                          () => null,
                                                    ),
                                              done:
                                                  'Slow motion saved for everyone.',
                                            ),
                                      child: const Text('Save slow motion'),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        if (_settingsTab == 1)
                          _Section(
                            title: 'POWER-UPS',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  settings.powerUps.isDefault
                                      ? 'Damage, times and spawning for Arsenal and All-Out: all at their defaults.'
                                      : 'Damage, times and spawning for Arsenal and All-Out: '
                                            '${settings.powerUps.overrides.length} changed from the defaults.',
                                  style: AppText.ui(
                                    14,
                                    FontWeight.w500,
                                    color: c.muted,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  key: const ValueKey('open-skill-management'),
                                  onPressed: _busy
                                      ? null
                                      : () async {
                                          final result =
                                              await Navigator.of(
                                                context,
                                              ).push<SkillManagementResult>(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      SkillManagementScreen(
                                                        initial: settings
                                                            .skillLibrary,
                                                        tuning:
                                                            settings.powerUps,
                                                      ),
                                                ),
                                              );
                                          if (!mounted || result == null) {
                                            return;
                                          }
                                          final current = AppSettingsScope.of(
                                            this.context,
                                          );
                                          await _save(
                                            current.copyWith(
                                              skillLibrary: result.library,
                                              powerUps: result.library.applyTo(
                                                result.tuning,
                                              ),
                                            ),
                                            done:
                                                'Skill library saved for everyone.',
                                          );
                                        },
                                  icon: const Icon(Icons.auto_awesome_motion),
                                  label: const Text('Open Skill Management'),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton(
                                  onPressed: _busy
                                      ? null
                                      : () async {
                                          final config =
                                              await Navigator.of(
                                                context,
                                              ).push<PowerUpConfig>(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      PowerUpTuningScreen(
                                                        initial:
                                                            settings.powerUps,
                                                      ),
                                                ),
                                              );
                                          if (config == null ||
                                              !mounted ||
                                              config == settings.powerUps) {
                                            return;
                                          }
                                          await _save(
                                            AppSettingsScope.of(
                                              this.context,
                                            ).copyWith(powerUps: config),
                                            done:
                                                'Power-up numbers saved for everyone.',
                                          );
                                        },
                                  child: const Text(
                                    'Edit power-up numbers (Legacy)',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton(
                                  key: const ValueKey('edit-item-rarities'),
                                  onPressed: _busy
                                      ? null
                                      : () async {
                                          final config =
                                              await Navigator.of(
                                                context,
                                              ).push<PowerUpConfig>(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      PowerUpRarityScreen(
                                                        initial:
                                                            settings.powerUps,
                                                      ),
                                                ),
                                              );
                                          if (!mounted ||
                                              config == null ||
                                              config == settings.powerUps) {
                                            return;
                                          }
                                          await _save(
                                            AppSettingsScope.of(
                                              this.context,
                                            ).copyWith(powerUps: config),
                                            done:
                                                'Item rarities saved for everyone.',
                                          );
                                        },
                                  child: const Text(
                                    'Edit item rarities (Legacy)',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_settingsTab == 1)
                          _Section(
                            title: 'POWER-UP TESTS',
                            child: OutlinedButton.icon(
                              key: const ValueKey('open-power-up-tests'),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const PowerUpTestScreen(),
                                ),
                              ),
                              icon: const Icon(Icons.science_outlined),
                              label: const Text('Open power-up tests'),
                            ),
                          ),
                        if (_settingsTab == 1)
                          _Section(
                            title: 'FINISHERS',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Preview every weapon, power-up, trap and core finishing move.',
                                  style: AppText.ui(
                                    14,
                                    FontWeight.w500,
                                    color: c.muted,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  key: const ValueKey('open-finisher-gallery'),
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const FinisherGalleryScreen(),
                                    ),
                                  ),
                                  icon: const Icon(Icons.movie_filter_rounded),
                                  label: const Text('Open finisher gallery'),
                                ),
                              ],
                            ),
                          ),
                        if (_settingsTab == 2)
                          _Section(
                            title: 'BALLS',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    'Outer glow in the arena',
                                    style: AppText.ui(
                                      14,
                                      FontWeight.w600,
                                      color: c.text,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Shown around every ball during matches and replays.',
                                    style: AppText.ui(
                                      13,
                                      FontWeight.w500,
                                      color: c.muted,
                                    ),
                                  ),
                                  value: settings.ballGlowEnabled,
                                  onChanged: _busy
                                      ? null
                                      : (v) => _save(
                                          settings.copyWith(ballGlowEnabled: v),
                                          done: v
                                              ? 'Ball glow on.'
                                              : 'Ball glow off.',
                                        ),
                                ),
                                Text(
                                  'Glow width: ${settings.ballGlowWidth.toStringAsFixed(1)}',
                                ),
                                Slider(
                                  key: const ValueKey('ball-glow-width-slider'),
                                  value: settings.ballGlowWidth,
                                  min: 1,
                                  max: 12,
                                  divisions: 22,
                                  onChanged: _busy
                                      ? null
                                      : (value) => _save(
                                          settings.copyWith(
                                            ballGlowWidth: value,
                                          ),
                                          done: 'Ball glow width saved.',
                                        ),
                                ),
                                Text(
                                  'Blood color',
                                  style: AppText.ui(
                                    14,
                                    FontWeight.w600,
                                    color: c.text,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    for (final color in const [
                                      Color(0xFFD9152B),
                                      Color(0xFFFF3B30),
                                      Color(0xFF8B0000),
                                      Color(0xFFFF6B35),
                                      Color(0xFF8E44AD),
                                      Color(0xFF2ECC71),
                                      Color(0xFF111111),
                                    ])
                                      ChoiceChip(
                                        key: ValueKey(
                                          'blood-${color.toARGB32()}',
                                        ),
                                        label: const SizedBox.square(
                                          dimension: 20,
                                        ),
                                        avatar: CircleAvatar(
                                          backgroundColor: color,
                                        ),
                                        selected:
                                            settings.bloodColor.toARGB32() ==
                                            color.toARGB32(),
                                        onSelected: _busy
                                            ? null
                                            : (_) => _save(
                                                settings.copyWith(
                                                  bloodColor: color,
                                                ),
                                                done: 'Blood color saved.',
                                              ),
                                      ),
                                    IconButton.outlined(
                                      key: const ValueKey('custom-blood-color'),
                                      tooltip: 'Custom blood color',
                                      onPressed: _busy
                                          ? null
                                          : () => _pickBloodColor(settings),
                                      icon: const Icon(Icons.colorize),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        if (_settingsTab == 2)
                          _Section(
                            title: 'EFFECT RENDERING',
                            child: Column(
                              children: [
                                Text(
                                  'Choose generated sprite artwork or the lightweight vector fallback for each effect family.',
                                  style: AppText.ui(
                                    13,
                                    FontWeight.w500,
                                    color: c.muted,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                for (final entry
                                    in <
                                      (
                                        String,
                                        EffectRenderMode,
                                        AppSettings Function(EffectRenderMode),
                                      )
                                    >[
                                      (
                                        'Projectiles',
                                        settings.projectileRenderMode,
                                        (mode) => settings.copyWith(
                                          projectileRenderMode: mode,
                                        ),
                                      ),
                                      (
                                        'Explosions',
                                        settings.explosionRenderMode,
                                        (mode) => settings.copyWith(
                                          explosionRenderMode: mode,
                                        ),
                                      ),
                                      (
                                        'Freeze effects',
                                        settings.freezeRenderMode,
                                        (mode) => settings.copyWith(
                                          freezeRenderMode: mode,
                                        ),
                                      ),
                                    ])
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child:
                                        DropdownButtonFormField<
                                          EffectRenderMode
                                        >(
                                          key: ValueKey(
                                            'effect-render-${entry.$1}',
                                          ),
                                          initialValue: entry.$2,
                                          decoration: InputDecoration(
                                            labelText: entry.$1,
                                          ),
                                          items: [
                                            for (final mode
                                                in EffectRenderMode.values)
                                              DropdownMenuItem(
                                                value: mode,
                                                child: Text(mode.label),
                                              ),
                                          ],
                                          onChanged: _busy
                                              ? null
                                              : (mode) {
                                                  if (mode != null) {
                                                    _save(
                                                      entry.$3(mode),
                                                      done:
                                                          '${entry.$1} rendering saved.',
                                                    );
                                                  }
                                                },
                                        ),
                                  ),
                              ],
                            ),
                          ),
                        if (_settingsTab == 2)
                          _Section(
                            title: 'BRANDING',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Arena text',
                                  style: AppText.ui(
                                    14,
                                    FontWeight.w600,
                                    color: c.text,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _arenaTitle,
                                  maxLength: 30,
                                  decoration: const InputDecoration(
                                    labelText: 'Large line',
                                    hintText: AppSettings.defaultArenaTitle,
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                                TextField(
                                  controller: _arenaSubtitle,
                                  maxLength: 50,
                                  decoration: const InputDecoration(
                                    labelText: 'Small line',
                                    hintText: AppSettings.defaultArenaSubtitle,
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                                OutlinedButton(
                                  onPressed:
                                      _busy ||
                                          _arenaTitle.text.trim().isEmpty ||
                                          _arenaSubtitle.text.trim().isEmpty
                                      ? null
                                      : () => _save(
                                          settings.copyWith(
                                            arenaTitle: _arenaTitle.text.trim(),
                                            arenaSubtitle: _arenaSubtitle.text
                                                .trim(),
                                          ),
                                          done: 'Arena text saved.',
                                        ),
                                  child: const Text('Save arena text'),
                                ),
                                const Divider(height: 32),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    'Tiled watermark on the winner card',
                                    style: AppText.ui(
                                      14,
                                      FontWeight.w600,
                                      color: c.text,
                                    ),
                                  ),
                                  value: settings.watermarkEnabled,
                                  onChanged: _busy
                                      ? null
                                      : (v) => _save(
                                          settings.copyWith(
                                            watermarkEnabled: v,
                                          ),
                                          done: v
                                              ? 'Watermark on.'
                                              : 'Watermark off.',
                                        ),
                                ),
                                TextField(
                                  controller: _watermark,
                                  maxLength: 30,
                                  enabled: settings.watermarkEnabled,
                                  decoration: const InputDecoration(
                                    hintText: AppSettings.defaultWatermark,
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                                OutlinedButton(
                                  onPressed:
                                      _busy ||
                                          !settings.watermarkEnabled ||
                                          _watermark.text.trim().isEmpty
                                      ? null
                                      : () => _save(
                                          settings.copyWith(
                                            watermarkText: _watermark.text
                                                .trim(),
                                          ),
                                          done: 'Watermark saved.',
                                        ),
                                  child: const Text('Save watermark text'),
                                ),
                              ],
                            ),
                          ),
                        if (_settingsTab == 1 && widget.customGroups != null)
                          _Section(
                            title: 'GROUPS',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                OutlinedButton(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => MyGroupsScreen(
                                        repository: widget.customGroups!,
                                        editRepository: widget.adminGroups,
                                        allGroups: true,
                                      ),
                                    ),
                                  ),
                                  child: const Text("Everyone's groups"),
                                ),
                                if (widget.adminGroups != null) ...[
                                  const SizedBox(height: 10),
                                  OutlinedButton(
                                    onPressed: _busy ? null : _cleanUpImages,
                                    child: const Text('Clean up unused images'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        if (_settingsTab == 3)
                          _Section(
                            title: 'ACCOUNT',
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _scope?.adminAuth?.email ?? 'Admin',
                                    style: AppText.ui(
                                      14,
                                      FontWeight.w600,
                                      color: c.text,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _busy ? null : _signOut,
                                  child: const Text('Sign out'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One music track: tap to make it the match music, ▶ to listen first.
class _TrackRow extends StatelessWidget {
  final MusicTrack track;
  final bool selected;
  final bool playing;
  final VoidCallback onPlay;
  final VoidCallback? onSelect;

  const _TrackRow({
    required this.track,
    required this.selected,
    required this.playing,
    required this.onPlay,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? c.surfaceHigh : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? c.text : c.border),
        ),
        child: InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: selected ? c.text : c.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.name,
                        style: AppText.ui(14, FontWeight.w700, color: c.text),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track.mood,
                        style: AppText.ui(12, FontWeight.w500, color: c.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: playing ? 'Stop' : 'Play ${track.name}',
                  onPressed: onPlay,
                  icon: Icon(
                    playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: AppText.mono(11, color: c.muted, letterSpacing: 1.6),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// A theme preview: its two colors, with the selected one ringed.
class _ThemeSwatch extends StatelessWidget {
  final ThemePreset preset;
  final bool selected;
  final VoidCallback? onTap;

  const _ThemeSwatch({
    required this.preset,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    return Tooltip(
      message: preset.name,
      child: Semantics(
        button: true,
        selected: selected,
        label: preset.name,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? c.text : Colors.transparent,
                width: 2,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: preset.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              alignment: Alignment.center,
              child: Text(
                'Aa',
                style: AppText.ui(
                  18,
                  FontWeight.w800,
                  color: preset.foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignInDialog extends StatefulWidget {
  const _SignInDialog();

  @override
  State<_SignInDialog> createState() => _SignInDialogState();
}

class _SignInDialogState extends State<_SignInDialog> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _rememberMe = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() =>
      Navigator.of(context).pop((_email.text, _password.text, _rememberMe));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Admin sign-in'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(labelText: 'Password'),
            onSubmitted: (_) => _submit(),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Remember me'),
            subtitle: const Text('Stay signed in on this device'),
            value: _rememberMe,
            onChanged: (value) => setState(() => _rememberMe = value ?? false),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Sign in')),
      ],
    );
  }
}
