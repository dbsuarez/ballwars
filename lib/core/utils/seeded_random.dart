import 'dart:math';

class SeededRandom {
  final Random _rng;

  SeededRandom(int seed) : _rng = Random(seed);

  double nextDouble() => _rng.nextDouble();

  int nextInt(int max) => _rng.nextInt(max);

  double nextDoubleRange(double min, double max) =>
      min + _rng.nextDouble() * (max - min);
}
