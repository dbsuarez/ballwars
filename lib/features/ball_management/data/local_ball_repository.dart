import 'package:flutter/material.dart';
import '../domain/ball_repository.dart';
import '../domain/custom_ball.dart';
import '../../../core/theme/app_colors.dart';

class LocalBallRepository implements BallRepository {
  final List<CustomBall> _balls = [
    const CustomBall(
      id: 'preset-usa',
      name: 'United States',
      primaryColor: AppColors.usaPrimary,
      glowColor: AppColors.usaGlow,
    ),
    const CustomBall(
      id: 'preset-russia',
      name: 'Russia',
      primaryColor: AppColors.russiaPrimary,
      glowColor: AppColors.russiaGlow,
    ),
    const CustomBall(
      id: 'preset-japan',
      name: 'Japan',
      primaryColor: AppColors.japanPrimary,
      glowColor: AppColors.japanGlow,
    ),
    const CustomBall(
      id: 'preset-brazil',
      name: 'Brazil',
      primaryColor: AppColors.brazilPrimary,
      glowColor: AppColors.brazilGlow,
    ),
  ];

  @override
  List<CustomBall> getAll() => List.unmodifiable(_balls);

  @override
  void add(CustomBall ball) => _balls.add(ball);

  @override
  void remove(String id) => _balls.removeWhere((b) => b.id == id);
}
