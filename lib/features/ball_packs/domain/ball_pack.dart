import '../../ball_management/domain/custom_ball.dart';

/// A built-in group of balls (Streaming, Shoes, Countries, ...).
class BallPack {
  final String id;
  final String name;
  final List<CustomBall> balls;

  const BallPack({required this.id, required this.name, required this.balls});

  /// Pack balls get ids like `pack:streaming/netflix`, unique across packs
  /// (the same brand can appear in two packs as two separate balls).
  static String ballId(String packId, String ballId) => 'pack:$packId/$ballId';

  static bool isPackBall(String id) => id.startsWith('pack:');
}
