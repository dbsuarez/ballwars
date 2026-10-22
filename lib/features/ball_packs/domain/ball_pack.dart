import '../../ball_management/domain/custom_ball.dart';

/// A built-in group of balls (Streaming, Shoes, Countries, ...). Match Setup
/// also wraps user groups in it.
class BallPack {
  final String id;
  final String name;
  final List<CustomBall> balls;

  /// A short label shown next to the category ("Mine", "Shared").
  final String? tag;

  const BallPack({required this.id, required this.name, required this.balls, this.tag});

  /// Pack balls get ids like `pack:streaming/netflix`, unique across packs
  /// (the same brand can appear in two packs as two separate balls).
  static String ballId(String packId, String ballId) => 'pack:$packId/$ballId';

  static bool isPackBall(String id) => id.startsWith('pack:');
}
