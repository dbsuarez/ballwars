import 'package:flutter/material.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/theme/app_theme.dart';
import '../../custom_groups/data/custom_group_repository.dart';
import '../../custom_groups/presentation/my_groups_screen.dart';
import '../domain/app_settings.dart';
import 'app_settings_scope.dart';

/// Settings. Players see only the admin sign-in; once the admin signs in
/// (email + password, listed in the `admins` table) they can change the
/// headline and theme for everyone and manage every user's groups.
class SettingsScreen extends StatefulWidget {
  final CustomGroupRepository? customGroups;

  const SettingsScreen({super.key, this.customGroups});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _headline = TextEditingController();
  final TextEditingController _watermark = TextEditingController();
  bool? _isAdmin;
  // Slow-motion choices before they are saved.
  int? _slowMotionLines;
  bool? _slowBeforeWin;
  double? _slowSeconds;
  bool _busy = false;
  String? _message;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isAdmin == null) {
      _headline.text = AppSettingsScope.of(context).headline;
      _watermark.text = AppSettingsScope.of(context).watermarkText;
      _checkAdmin();
    }
  }

  @override
  void dispose() {
    _headline.dispose();
    _watermark.dispose();
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
      if (mounted) setState(() => _message = '$e'.replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() async {
    final result = await showDialog<(String, String)>(context: context, builder: (_) => const _SignInDialog());
    if (result == null) return;
    await _run(() async {
      await _scope!.adminAuth!.signIn(result.$1, result.$2);
      if (mounted) setState(() => _isAdmin = true);
    });
  }

  Future<void> _signOut() => _run(() async {
        await _scope!.adminAuth!.signOut();
        if (mounted) setState(() => _isAdmin = false);
      });

  void _togglePreview(MusicTrack track) {
    final audio = GameAudio.instance;
    if (audio.previewing == track.id) {
      audio.stopPreview();
    } else {
      audio.preview(track, onDone: () {
        if (mounted) setState(() {});
      });
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: _busy ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator()) : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(_message!, style: AppText.ui(13, FontWeight.w600, color: c.muted)),
            ),
          if (!hasBackend)
            Text('Settings need a connection to the Ball Wars server.', style: AppText.ui(14, FontWeight.w500, color: c.muted))
          else if (_isAdmin == null)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_isAdmin == false)
            _Section(
              title: 'ADMIN',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'The headline, theme and match music are set by the admin for everyone.',
                    style: AppText.ui(14, FontWeight.w500, color: c.muted, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(onPressed: _busy ? null : _signIn, child: const Text('Admin sign-in')),
                ],
              ),
            )
          else ...[
            _Section(
              title: 'HEADLINE',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _headline,
                    maxLength: 30,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(hintText: AppSettings.defaultHeadline),
                  ),
                  FilledButton(
                    onPressed: _busy || _headline.text.trim().isEmpty
                        ? null
                        : () => _save(settings.copyWith(headline: _headline.text.trim()), done: 'Headline saved for everyone.'),
                    child: const Text('Save headline'),
                  ),
                ],
              ),
            ),
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
                      onTap: _busy ? null : () => _save(settings.copyWith(themeId: preset.id), done: 'Theme set for everyone.'),
                    ),
                ],
              ),
            ),
            _Section(
              title: 'MUSIC',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final track in MusicTrack.all)
                    _TrackRow(
                      track: track,
                      selected: track.id == settings.musicId,
                      playing: GameAudio.instance.previewing == track.id,
                      onPlay: () => _togglePreview(track),
                      onSelect: _busy || track.id == settings.musicId
                          ? null
                          : () => _save(
                                settings.copyWith(musicId: track.id),
                                done: '"${track.name}" is now the match music for everyone.',
                              ),
                    ),
                ],
              ),
            ),
            _Section(
              title: 'SLOW MOTION',
              child: Builder(
                builder: (context) {
                  final beforeWin = _slowBeforeWin ?? settings.slowMotionBeforeWinSeconds != null;
                  final lines = _slowMotionLines ?? settings.slowMotionLines;
                  final seconds = _slowSeconds ??
                      settings.slowMotionBeforeWinSeconds ??
                      AppSettings.defaultSlowMotionBeforeWinSeconds;
                  final changed = beforeWin
                      ? settings.slowMotionBeforeWinSeconds != seconds
                      : settings.slowMotionBeforeWinSeconds != null || settings.slowMotionLines != lines;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('By lines')),
                          ButtonSegment(value: true, label: Text('Before the win')),
                        ],
                        selected: {beforeWin},
                        onSelectionChanged: _busy ? null : (v) => setState(() => _slowBeforeWin = v.first),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        beforeWin
                            ? 'Starts ${seconds.toStringAsFixed(1)} s before the winning cut.'
                            : lines == 0
                            ? 'Off: matches never slow down.'
                            : 'Starts when one of the last two balls is down to $lines lines or fewer for good.',
                        style: AppText.ui(14, FontWeight.w600, color: c.text),
                      ),
                      if (beforeWin)
                        Slider(
                          value: seconds,
                          min: 0.5,
                          max: 5,
                          divisions: 9,
                          label: '${seconds.toStringAsFixed(1)} s',
                          onChanged: _busy ? null : (v) => setState(() => _slowSeconds = v),
                        )
                      else
                        Slider(
                          value: lines.toDouble(),
                          min: 0,
                          max: 60,
                          divisions: 60,
                          label: lines == 0 ? 'Off' : '$lines',
                          onChanged: _busy ? null : (v) => setState(() => _slowMotionLines = v.round()),
                        ),
                      Text(
                        beforeWin
                            ? 'Game time; slow motion plays it 4x slower. The app plays each match ahead to know the moment.'
                            : 'Default ${AppSettings.defaultSlowMotionLines}. Each ball starts with about 90 lines. '
                                  "A ball that will recover doesn't trigger it.",
                        style: AppText.ui(12, FontWeight.w500, color: c.muted, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _busy || !changed
                            ? null
                            : () => _save(
                                  beforeWin
                                      ? settings.copyWith(slowMotionBeforeWinSeconds: () => seconds)
                                      : settings.copyWith(slowMotionLines: lines, slowMotionBeforeWinSeconds: () => null),
                                  done: 'Slow motion saved for everyone.',
                                ),
                        child: const Text('Save slow motion'),
                      ),
                    ],
                  );
                },
              ),
            ),
            _Section(
              title: 'WATERMARK',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Tiled watermark on the winner card', style: AppText.ui(14, FontWeight.w600, color: c.text)),
                    value: settings.watermarkEnabled,
                    onChanged: _busy
                        ? null
                        : (v) => _save(settings.copyWith(watermarkEnabled: v), done: v ? 'Watermark on.' : 'Watermark off.'),
                  ),
                  TextField(
                    controller: _watermark,
                    maxLength: 30,
                    enabled: settings.watermarkEnabled,
                    decoration: const InputDecoration(hintText: AppSettings.defaultWatermark),
                    onChanged: (_) => setState(() {}),
                  ),
                  OutlinedButton(
                    onPressed: _busy || !settings.watermarkEnabled || _watermark.text.trim().isEmpty
                        ? null
                        : () => _save(settings.copyWith(watermarkText: _watermark.text.trim()), done: 'Watermark saved.'),
                    child: const Text('Save watermark text'),
                  ),
                ],
              ),
            ),
            if (widget.customGroups != null)
              _Section(
                title: 'GROUPS',
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => MyGroupsScreen(repository: widget.customGroups!, allGroups: true)),
                  ),
                  child: const Text("Everyone's groups"),
                ),
              ),
            _Section(
              title: 'ACCOUNT',
              child: Row(
                children: [
                  Expanded(
                    child: Text(_scope?.adminAuth?.email ?? 'Admin', style: AppText.ui(14, FontWeight.w600, color: c.text)),
                  ),
                  TextButton(onPressed: _busy ? null : _signOut, child: const Text('Sign out')),
                ],
              ),
            ),
          ],
        ],
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
                  selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  size: 20,
                  color: selected ? c.text : c.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(track.name, style: AppText.ui(14, FontWeight.w700, color: c.text)),
                      const SizedBox(height: 2),
                      Text(track.mood, style: AppText.ui(12, FontWeight.w500, color: c.muted)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: playing ? 'Stop' : 'Play ${track.name}',
                  onPressed: onPlay,
                  icon: Icon(playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppText.mono(11, color: c.muted, letterSpacing: 1.6)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// A theme preview: its two colors, with the selected one ringed.
class _ThemeSwatch extends StatelessWidget {
  final ThemePreset preset;
  final bool selected;
  final VoidCallback? onTap;

  const _ThemeSwatch({required this.preset, required this.selected, this.onTap});

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
              border: Border.all(color: selected ? c.text : Colors.transparent, width: 2),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: preset.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              alignment: Alignment.center,
              child: Text('Aa', style: AppText.ui(18, FontWeight.w800, color: preset.foreground)),
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

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop((_email.text, _password.text));

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
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Sign in')),
      ],
    );
  }
}
