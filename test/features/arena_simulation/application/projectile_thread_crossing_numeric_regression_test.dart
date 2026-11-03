
import 'package:ballwars/features/arena_simulation/domain/arena_boundary_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('very long swept projectile crosses a short thread', () {
    expect(segmentsProperlyCross(
      const Offset(-1e200, 0), const Offset(1e200, 0),
      const Offset(0, -10), const Offset(0, 10)), isTrue);
  });

  test('very long parallel shot does not cut a thread', () {
    expect(segmentsProperlyCross(
      const Offset(-1e200, 20), const Offset(1e200, 20),
      const Offset(0, -10), const Offset(0, 10)), isFalse);
  });

  test('touching an endpoint does not count as a proper crossing', () {
    expect(segmentsProperlyCross(
      const Offset(-10, 0), const Offset(0, 0),
      const Offset(0, 0), const Offset(0, 10)), isFalse);
  });

  test('ordinary crossing remains supported regardless of direction', () {
    expect(segmentsProperlyCross(
      const Offset(-10, 0), const Offset(10, 0),
      const Offset(0, 10), const Offset(0, -10)), isTrue);
  });

  test('nonfinite geometry cannot cut a thread', () {
    expect(segmentsProperlyCross(
      const Offset(double.nan, 0), const Offset(10, 0),
      const Offset(0, -10), const Offset(0, 10)), isFalse);
  });
}
