import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/neon_button.dart';
import 'features/ball_management/data/local_ball_repository.dart';
import 'features/ball_management/domain/custom_ball.dart';
import 'features/ball_management/presentation/ball_library_screen.dart';
import 'features/ball_packs/data/ball_pack_repository.dart';
import 'features/arena_simulation/presentation/arena_battle_screen.dart';
import 'features/match_setup/domain/match_config.dart';
import 'features/match_setup/presentation/match_setup_screen.dart';
import 'features/replay_export/domain/replay_link.dart';

class BallWarsApp extends StatelessWidget {
  const BallWarsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = LocalBallRepository();

    return MaterialApp(
      title: 'Ball Wars',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: _HomeScreen(repository: repository),
    );
  }
}

class _HomeScreen extends StatefulWidget {
  final LocalBallRepository repository;

  const _HomeScreen({required this.repository});

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
    var packBalls = const <String, CustomBall>{};
    if (ReplayLink.usesPacks(uri)) {
      try {
        packBalls = {for (final pack in await _packs.load()) for (final b in pack.balls) b.id: b};
      } catch (_) {
        return; // Packs unreachable: stay on the home screen.
      }
    }
    final link = ReplayLink.fromUri(uri, presets: LocalBallRepository.presets, packBalls: packBalls);
    if (link == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ArenaBattleScreen(
          config: MatchConfig(contestants: link.contestants, speedMultiplier: link.speedMultiplier),
          seed: link.seed,
        ),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final repository = widget.repository;
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
            const SizedBox(height: 16),
            NeonButton(
              label: 'MATCH SETUP',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => MatchSetupScreen(
                  repository: repository,
                  packRepository: _packs,
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
