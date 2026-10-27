import 'package:flutter/material.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/canvas_action_glyph.dart';
import '../../arena_simulation/domain/power_up.dart';
import '../../arena_simulation/presentation/finisher_profile.dart';
import '../../arena_simulation/presentation/harpoon_cinematic.dart';
import '../../arena_simulation/presentation/power_up_sprites.dart';
import '../../arena_simulation/presentation/power_up_name.dart';
import '../../ball_management/domain/custom_ball.dart';
import 'app_settings_scope.dart';

/// Admin-only gallery for playing every finishing move without running a match.
class FinisherGalleryScreen extends StatefulWidget {
  const FinisherGalleryScreen({super.key});

  @override
  State<FinisherGalleryScreen> createState() => _FinisherGalleryScreenState();
}

class _FinisherGalleryScreenState extends State<FinisherGalleryScreen> {
  bool? _isAdmin;

  static const _winner = CustomBall(
    id: 'finisher-winner',
    name: 'Ball A',
    primaryColor: Color(0xFFFF5B4D),
    glowColor: Color(0xFFFFA38F),
  );
  static const _loser = CustomBall(
    id: 'finisher-loser',
    name: 'Ball B',
    primaryColor: Color(0xFF4D9DFF),
    glowColor: Color(0xFF7EDBFF),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isAdmin == null) {
      _checkAccess();
    }
  }

  Future<void> _checkAccess() async {
    final admin =
        await AppSettingsScope.maybeScope(context)?.adminAuth?.isAdmin() ??
        false;
    if (mounted) setState(() => _isAdmin = admin);
  }

  Future<void> _play(String move) async {
    final profile = FinisherProfile.forMove(move);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (previewContext) => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: HarpoonCinematic(
                    winner: _winner,
                    loser: _loser,
                    move: move,
                    onHookFired: () => _launchSound(profile),
                    onImpact: () => _impactSound(profile),
                    onFinished: () {
                      GameAudio.instance.win();
                      Navigator.of(previewContext).maybePop();
                    },
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    tooltip: 'Close preview',
                    onPressed: () => Navigator.of(previewContext).maybePop(),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xB3000000),
                      foregroundColor: Colors.white,
                      side: BorderSide(color: profile.accent, width: 2),
                    ),
                    icon: const CanvasActionGlyph(
                      CanvasActionGlyphType.close,
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _launchSound(FinisherProfile profile) {
    final audio = GameAudio.instance;
    switch (profile.style) {
      case FinisherStyle.projectile:
        audio.shot();
      case FinisherStyle.barrage:
        profile.move == 'Gatling' ? audio.gatling() : audio.shotgun();
      case FinisherStyle.melee:
        audio.slash();
      case FinisherStyle.blast:
      case FinisherStyle.trap:
        audio.bomb();
      case FinisherStyle.hook:
        audio.shotgun();
      case FinisherStyle.aura:
        audio.shield();
      case FinisherStyle.warp:
        audio.pickup();
    }
  }

  void _impactSound(FinisherProfile profile) {
    final audio = GameAudio.instance;
    switch (profile.style) {
      case FinisherStyle.projectile:
      case FinisherStyle.barrage:
      case FinisherStyle.hook:
        audio.hit();
      case FinisherStyle.melee:
        audio.collide();
      case FinisherStyle.blast:
      case FinisherStyle.trap:
        audio.bomb();
      case FinisherStyle.aura:
        audio.shield();
      case FinisherStyle.warp:
        audio.pickup();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    final tuning = AppSettingsScope.of(context).powerUps;
    final damaging = PowerUpKind.values.where(
      (item) => item.dealsDamage(tuning),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Finisher Gallery')),
      body: _isAdmin == null
          ? const Center(child: CircularProgressIndicator())
          : _isAdmin == false
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Admin access required.',
                  style: AppText.ui(16, FontWeight.w700, color: c.muted),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Text(
                  'Play the real full-screen sequence with its effects, yells and sounds. It returns here automatically.',
                  style: AppText.ui(
                    14,
                    FontWeight.w500,
                    color: c.muted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                _group(
                  'WEAPONS',
                  damaging.where((item) => item.isWeapon).toList(),
                ),
                _group(
                  'POWER-UPS',
                  damaging.where((item) => item.isPowerUp).toList(),
                ),
                _group('TRAPS', damaging.where((item) => item.isTrap).toList()),
                _GalleryGroup(
                  title: 'ARENA TRAPS',
                  children: [
                    for (final move in ['Quicksand', 'Laser Gate'])
                      _FinisherCard(
                        profile: FinisherProfile.forMove(move),
                        icon: const Icon(Icons.warning_amber_rounded, size: 36),
                        onPlay: () => _play(move),
                      ),
                  ],
                ),
                _coreGroup(),
              ],
            ),
    );
  }

  Widget _group(String title, List<PowerUpKind> items) => items.isEmpty
      ? const SizedBox.shrink()
      : _GalleryGroup(
          title: title,
          children: [
            for (final item in items)
              _FinisherCard(
                key: ValueKey('finisher-${item.name}'),
                profile: FinisherProfile.forMove(item.label),
                icon: PowerUpIcon(item, size: 36),
                onPlay: () => _play(item.label),
              ),
          ],
        );

  Widget _coreGroup() => _GalleryGroup(
    title: 'CORE MOVES',
    children: [
      for (final move in const ['Collision', 'Thread cut'])
        _FinisherCard(
          profile: FinisherProfile.forMove(move),
          icon: Icon(
            move == 'Collision'
                ? Icons.blur_circular_rounded
                : Icons.content_cut_rounded,
            size: 34,
          ),
          onPlay: () => _play(move),
        ),
    ],
  );
}

class _GalleryGroup extends StatelessWidget {
  const _GalleryGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Text(
          title,
          style: AppText.ui(
            12,
            FontWeight.w800,
            color: BallWarsColors.of(context).muted,
            letterSpacing: 1.8,
          ),
        ),
      ),
      LayoutBuilder(
        builder: (context, bounds) {
          final width = bounds.maxWidth >= 680
              ? (bounds.maxWidth - 12) / 2
              : bounds.maxWidth;
          return Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              for (final child in children)
                SizedBox(width: width, child: child),
            ],
          );
        },
      ),
    ],
  );
}

class _FinisherCard extends StatelessWidget {
  const _FinisherCard({
    super.key,
    required this.profile,
    required this.icon,
    required this.onPlay,
  });

  final FinisherProfile profile;
  final Widget icon;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    final item = PowerUpKind.values
        .where((kind) => kind.label == profile.move)
        .firstOrNull;
    return Card(
      margin: EdgeInsets.zero,
      color: c.surfaceHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            SizedBox(width: 42, height: 42, child: Center(child: icon)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item != null)
                    PowerUpName(
                      item,
                      tuning: AppSettingsScope.of(context).powerUps,
                      style: AppText.ui(14, FontWeight.w800, color: c.text),
                    )
                  else
                    Text(
                      profile.move,
                      style: AppText.ui(14, FontWeight.w800, color: c.text),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    '${profile.yell}  •  ${profile.impactYell}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.ui(11, FontWeight.w600, color: c.muted),
                  ),
                ],
              ),
            ),
            IconButton.filled(
              key: ValueKey('play-finisher-${profile.move}'),
              tooltip: 'Play ${profile.move} finisher',
              onPressed: onPlay,
              style: IconButton.styleFrom(
                backgroundColor: profile.color,
                foregroundColor: Colors.black,
                side: BorderSide(color: profile.accent, width: 2),
              ),
              icon: const CanvasActionGlyph(
                CanvasActionGlyphType.play,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
