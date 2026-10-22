import '../domain/ball_repository.dart';
import '../domain/custom_ball.dart';
import '../../../core/theme/app_colors.dart';

class LocalBallRepository implements BallRepository {
  /// Balls every copy of the app ships with. Replay links refer to these by
  /// id, so they must stay stable even if a user removes them locally.
  static const List<CustomBall> presets = [
    CustomBall(
      id: 'preset-usa',
      name: 'United States',
      primaryColor: AppColors.usaPrimary,
      glowColor: AppColors.usaGlow,
    ),
    CustomBall(
      id: 'preset-russia',
      name: 'Russia',
      primaryColor: AppColors.russiaPrimary,
      glowColor: AppColors.russiaGlow,
    ),
    CustomBall(
      id: 'preset-japan',
      name: 'Japan',
      primaryColor: AppColors.japanPrimary,
      glowColor: AppColors.japanGlow,
    ),
    CustomBall(
      id: 'preset-brazil',
      name: 'Brazil',
      primaryColor: AppColors.brazilPrimary,
      glowColor: AppColors.brazilGlow,
    ),
  ];

  final List<CustomBall> _balls = [...presets];

  @override
  List<CustomBall> getAll() => List.unmodifiable(_balls);

  @override
  void add(CustomBall ball) => _balls.add(ball);

  @override
  void remove(String id) => _balls.removeWhere((b) => b.id == id);
}
