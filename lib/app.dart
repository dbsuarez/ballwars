import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/arena_simulation/presentation/arena_battle_screen.dart';
import 'features/ball_management/data/local_ball_repository.dart';
import 'features/ball_management/domain/custom_ball.dart';
import 'features/ball_packs/data/ball_pack_repository.dart';
import 'features/custom_groups/data/custom_group_repository.dart';
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

  /// App-wide settings and the admin login; null keeps the defaults.
  final AppSettingsRepository? settingsRepository;
  final AdminAuth? adminAuth;

  /// Short share links; null shares long links only.
  final ShortLinkRepository? shortLinks;

  const BallWarsApp({super.key, this.customGroups, this.settingsRepository, this.adminAuth, this.shortLinks});

  @override
  State<BallWarsApp> createState() => _BallWarsAppState();
}

class _BallWarsAppState extends State<BallWarsApp> {
  final ValueNotifier<AppSettings> _settings = ValueNotifier(AppSettings.defaults);

  @override
  void initState() {
    super.initState();
    _loadSettings();
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
          home: _HomeScreen(customGroups: widget.customGroups, shortLinks: widget.shortLinks),
        ),
      ),
    );
  }
}

class _HomeScreen extends StatefulWidget {
  final CustomGroupRepository? customGroups;
  final ShortLinkRepository? shortLinks;

  const _HomeScreen({this.customGroups, this.shortLinks});

  @override
  State<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<_HomeScreen> {
  // Built-in packs (Streaming, Countries, ...), loaded once and shared.
  final BallPackRepository _packs = BallPackRepository();

  @override
  void initState() {
    super.initState();
    // Opened from a shared replay link (web): go straight to that match.
    _openReplayLink(Uri.base);
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
          for (final b in await widget.customGroups!.ballsById(ReplayLink.groupBallIds(uri))) b.id: b,
      };
    } catch (_) {
      return; // Packs or groups unreachable: stay on the home screen.
    }
    final link = ReplayLink.fromUri(uri, presets: LocalBallRepository.presets, packBalls: extraBalls);
    if (link == null) return;
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
            showEffects: link.showEffects,
          ),
          seed: link.seed,
        ),
      ),
    );
  }

  void _openMatchSetup() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchSetupScreen(
          packRepository: _packs,
          customGroups: widget.customGroups,
          onStartBattle: (config) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => ArenaBattleScreen(config: config)));
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
                      Text('BALL WARS', style: AppText.ui(15, FontWeight.w800, color: c.text, letterSpacing: 2.6)),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Settings',
                        icon: const Icon(Icons.tune),
                        onPressed: () =>
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsScreen(customGroups: customGroups))),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: CustomPaint(painter: _HomeArenaPainter(rim: c.text)),
                      ),
                    ),
                  ),
                  Text(AppSettingsScope.of(context).headline.toLowerCase().replaceFirstMapped(RegExp(r'^\w'), (m) => m[0]!.toUpperCase()),
                      style: AppText.ui(40, FontWeight.w800, color: c.text, height: 1.05, letterSpacing: -0.8)),
                  const SizedBox(height: 10),
                  Text(
                    'Pick two to four balls. Each holds a fan of lines to the rim — cut them all and it\'s out.',
                    style: AppText.ui(15, FontWeight.w500, color: c.muted, height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(onPressed: _openMatchSetup, child: const Text('Start a match')),
                  if (customGroups != null) ...[
                    const SizedBox(height: 12),
                    _HomeTile(
                      title: 'My groups',
                      subtitle: 'Your own categories of balls',
                      onTap: () => Navigator.of(
                        context,
                      ).push(MaterialPageRoute(builder: (_) => MyGroupsScreen(repository: customGroups))),
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

  const _HomeTile({required this.title, required this.subtitle, required this.onTap});

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
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.ui(14, FontWeight.w700, color: c.text)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: AppText.ui(12, FontWeight.w500, color: c.muted)),
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
        canvas.drawLine(center + Offset(math.cos(a), math.sin(a)) * r, ball, paint);
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

    fan(center + Offset(r * 0.25, -r * 0.32), const Color(0xFF4FD1C5), 200, 330);
    fan(center + Offset(-r * 0.29, r * 0.29), const Color(0xFFFF7A59), 15, 150);
  }

  @override
  bool shouldRepaint(_HomeArenaPainter oldDelegate) => oldDelegate.rim != rim;
}
