import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/neon_button.dart';
import 'features/ball_management/data/local_ball_repository.dart';
import 'features/ball_management/domain/custom_ball.dart';
import 'features/ball_management/presentation/ball_library_screen.dart';
import 'features/ball_packs/data/ball_pack_repository.dart';
import 'features/arena_simulation/presentation/arena_battle_screen.dart';
import 'features/custom_groups/data/custom_group_repository.dart';
import 'features/custom_groups/presentation/my_groups_screen.dart';
import 'features/match_setup/domain/match_config.dart';
import 'features/match_setup/presentation/match_setup_screen.dart';
import 'features/replay_export/domain/replay_link.dart';

class BallWarsApp extends StatelessWidget {
  /// User-made groups (Supabase); null hides My Groups (e.g. in tests).
  final CustomGroupRepository? customGroups;

  const BallWarsApp({super.key, this.customGroups});

  @override
  Widget build(BuildContext context) {
    final repository = LocalBallRepository();

    return MaterialApp(
      title: 'Ball Wars',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: _HomeScreen(repository: repository, customGroups: customGroups),
    );
  }
}

class _HomeScreen extends StatefulWidget {
  final LocalBallRepository repository;
  final CustomGroupRepository? customGroups;

  const _HomeScreen({required this.repository, this.customGroups});

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
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ArenaBattleScreen(
        config: MatchConfig(contestants: link.contestants, speedMultiplier: link.speedMultiplier),
        seed: link.seed,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final repository = widget.repository;
    final customGroups = widget.customGroups;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ball Wars', style: TextStyle(fontSize: 32, color: Colors.white)),
            const SizedBox(height: 32),
            NeonButton(
              label: 'BALL LIBRARY',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => BallLibraryScreen(repository: repository),
              )),
            ),
            if (customGroups != null) ...[
              const SizedBox(height: 16),
              NeonButton(
                label: 'MY GROUPS',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MyGroupsScreen(repository: customGroups),
                )),
              ),
            ],
            const SizedBox(height: 16),
            NeonButton(
              label: 'MATCH SETUP',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => MatchSetupScreen(
                  repository: repository,
                  packRepository: _packs,
                  customGroups: customGroups,
                  onStartBattle: (config) {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ArenaBattleScreen(config: config),
                    ));
                  },
                ),
              )),
            ),
          ],
        ),
      ),
    );
  }
}
