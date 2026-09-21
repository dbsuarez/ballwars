# Ball Wars Core Simulator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a working, mobile-responsive Flutter (web + iOS/Android) Ball Wars simulator: ball creation, match setup, and a live 2-4 player physics/territory battle with canvas rendering — playable end to end on a single device.

**Architecture:** Clean feature-first structure (`ball_management`, `match_setup`, `arena_simulation`) separating domain (physics/territory/particles — pure Dart, unit-testable), application (the simulation controller driving a fixed-timestep loop), and presentation (CustomPainter canvas rendering + Flutter widgets). All randomness flows through a single seeded RNG from day one so matches are deterministic — required for the sharing/replay feature planned in Phase 2, and free to build now.

**Tech Stack:** Flutter 3.38 (stable), Dart 3.10, `file_picker` for cross-platform image bytes, `flutter_test` for unit/widget tests. No Flame engine — pure Dart + Canvas API.

**Spec:**
- `docs/CLAUDE_CODE_BALL_WARS_SPEC.md` (base simulator spec)
- `docs/superpowers/specs/2026-09-21-ball-wars-mobile-sharing-design.md` (mobile + determinism requirements — Phase 2 sharing/gallery itself is out of scope for this plan, but §3's determinism requirement is implemented here)

## Global Constraints

- Do NOT use the Flame engine — physics and rendering are pure Dart + `CustomPainter`/`Ticker`.
- Images must be handled as `Uint8List` (no `dart:io` `File`) for web compatibility.
- Arena is a circle centered at `Offset(0, 0)` with radius `R`; ball radius `r = 0.08 * R`.
- All randomness (bounce jitter, collision winner tiebreak, steal amount, particle spawn) must go through a single seeded RNG owned by the match (`core/utils/seeded_random.dart`), never raw `Random()` — this is required for future replay determinism (see mobile-sharing design §3).
- The simulation physics step must run on a fixed timestep (1/60s), accumulating real elapsed time into fixed steps — required so replays don't diverge (mobile-sharing design §3).
- Starter presets: United States `#28E21B`/`#70FF66`, Russia `#00E5FF`/`#80F3FF`, Japan `#FF1744`/`#FF617B`, Brazil `#FFEA00`/`#FFF370`.
- Arena screen must be responsive: square arena scaled to shortest screen dimension, portrait mobile stacks score bar below the arena, landscape/web places it beside.
- Touch targets ≥44x44 logical px.

---

## Task 1: Scaffold Flutter Project & Theme

**Files:**
- Create: `pubspec.yaml`
- Create: `lib/main.dart`
- Create: `lib/app.dart`
- Create: `lib/core/theme/app_colors.dart`
- Create: `lib/core/theme/app_theme.dart`
- Create: `test/widget_test_smoke.dart`

**Interfaces:**
- Produces: `AppColors` (static const `Color` fields: `background`, `arenaDiscStart`, `arenaDiscEnd`, `usaPrimary`/`usaGlow`, `russiaPrimary`/`russiaGlow`, `japanPrimary`/`japanGlow`, `brazilPrimary`/`brazilGlow`), `AppTheme.dark()` returning a `ThemeData`, `BallWarsApp` (a `StatelessWidget` root widget).

- [ ] **Step 1: Create the Flutter project skeleton**

Run: `flutter create --org com.ballwars --project-name ballwars --platforms=web,android,ios .`

Expected: generates `pubspec.yaml`, `lib/main.dart`, `android/`, `ios/`, `web/` and other platform folders in the current directory.

- [ ] **Step 2: Add dependencies to `pubspec.yaml`**

Edit `pubspec.yaml`'s `dependencies:` section to include:

```yaml
dependencies:
  flutter:
    sdk: flutter
  file_picker: ^8.1.2
  cupertino_icons: ^1.0.8

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
```

Run: `flutter pub get`
Expected: resolves successfully with no errors.

- [ ] **Step 3: Create `lib/core/theme/app_colors.dart`**

```dart
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color background = Color(0xFF020408);
  static const Color arenaDiscStart = Color(0xFF0A0E17);
  static const Color arenaDiscEnd = Color(0xFF020408);
  static const Color rimGlow = Color(0xFFFFFFFF);

  static const Color usaPrimary = Color(0xFF28E21B);
  static const Color usaGlow = Color(0xFF70FF66);

  static const Color russiaPrimary = Color(0xFF00E5FF);
  static const Color russiaGlow = Color(0xFF80F3FF);

  static const Color japanPrimary = Color(0xFFFF1744);
  static const Color japanGlow = Color(0xFFFF617B);

  static const Color brazilPrimary = Color(0xFFFFEA00);
  static const Color brazilGlow = Color(0xFFFFF370);
}
```

- [ ] **Step 4: Create `lib/core/theme/app_theme.dart`**

```dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.russiaPrimary,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
  }
}
```

- [ ] **Step 5: Create `lib/app.dart`**

```dart
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';

class BallWarsApp extends StatelessWidget {
  const BallWarsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ball Wars',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const Scaffold(
        body: Center(child: Text('Ball Wars')),
      ),
    );
  }
}
```

- [ ] **Step 6: Replace `lib/main.dart`**

```dart
import 'package:flutter/material.dart';
import 'app.dart';

void main() {
  runApp(const BallWarsApp());
}
```

- [ ] **Step 7: Replace the generated smoke test**

Delete the default `test/widget_test.dart` generated by `flutter create` and create `test/widget_test_smoke.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/app.dart';

void main() {
  testWidgets('BallWarsApp builds and shows title', (tester) async {
    await tester.pumpWidget(const BallWarsApp());
    expect(find.text('Ball Wars'), findsOneWidget);
  });
}
```

- [ ] **Step 8: Run the test**

Run: `flutter test test/widget_test_smoke.dart`
Expected: PASS (1 test).

- [ ] **Step 9: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/ test/ android/ ios/ web/ macos/ linux/ windows/ .gitignore
git commit -m "Scaffold Flutter project with dark theme and app shell"
```

---

## Task 2: Core Math Utilities — Seeded RNG & Vector Math

**Files:**
- Create: `lib/core/utils/seeded_random.dart`
- Create: `lib/core/utils/math_utils.dart`
- Test: `test/core/utils/seeded_random_test.dart`
- Test: `test/core/utils/math_utils_test.dart`

**Interfaces:**
- Produces:
  - `SeededRandom(int seed)` with `double nextDouble()`, `int nextInt(int max)`, `double nextDoubleRange(double min, double max)`.
  - `MathUtils.clampDouble(double value, double min, double max) -> double`
  - `MathUtils.distance(Offset a, Offset b) -> double`
  - `MathUtils.rotateVector(Offset v, double radians) -> Offset`

- [ ] **Step 1: Write failing tests for `SeededRandom`**

```dart
// test/core/utils/seeded_random_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/utils/seeded_random.dart';

void main() {
  test('same seed produces identical sequence', () {
    final a = SeededRandom(42);
    final b = SeededRandom(42);
    final seqA = List.generate(10, (_) => a.nextDouble());
    final seqB = List.generate(10, (_) => b.nextDouble());
    expect(seqA, equals(seqB));
  });

  test('nextDoubleRange stays within bounds', () {
    final r = SeededRandom(7);
    for (var i = 0; i < 100; i++) {
      final v = r.nextDoubleRange(10, 20);
      expect(v, inInclusiveRange(10, 20));
    }
  });

  test('nextInt respects max exclusive bound', () {
    final r = SeededRandom(1);
    for (var i = 0; i < 100; i++) {
      final v = r.nextInt(5);
      expect(v, greaterThanOrEqualTo(0));
      expect(v, lessThan(5));
    }
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/utils/seeded_random_test.dart`
Expected: FAIL — `seeded_random.dart` doesn't exist yet.

- [ ] **Step 3: Implement `SeededRandom`**

```dart
// lib/core/utils/seeded_random.dart
import 'dart:math';

class SeededRandom {
  final Random _rng;

  SeededRandom(int seed) : _rng = Random(seed);

  double nextDouble() => _rng.nextDouble();

  int nextInt(int max) => _rng.nextInt(max);

  double nextDoubleRange(double min, double max) =>
      min + _rng.nextDouble() * (max - min);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/utils/seeded_random_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Write failing tests for `MathUtils`**

```dart
// test/core/utils/math_utils_test.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/utils/math_utils.dart';

void main() {
  test('clampDouble clamps to range', () {
    expect(MathUtils.clampDouble(5, 0, 10), 5);
    expect(MathUtils.clampDouble(-5, 0, 10), 0);
    expect(MathUtils.clampDouble(15, 0, 10), 10);
  });

  test('distance computes euclidean distance', () {
    final d = MathUtils.distance(const Offset(0, 0), const Offset(3, 4));
    expect(d, closeTo(5.0, 1e-9));
  });

  test('rotateVector rotates by 90 degrees', () {
    final rotated = MathUtils.rotateVector(const Offset(1, 0), math.pi / 2);
    expect(rotated.dx, closeTo(0.0, 1e-9));
    expect(rotated.dy, closeTo(1.0, 1e-9));
  });
}
```

- [ ] **Step 6: Run tests to verify they fail**

Run: `flutter test test/core/utils/math_utils_test.dart`
Expected: FAIL — `math_utils.dart` doesn't exist yet.

- [ ] **Step 7: Implement `MathUtils`**

```dart
// lib/core/utils/math_utils.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

class MathUtils {
  MathUtils._();

  static double clampDouble(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  static double distance(Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  static Offset rotateVector(Offset v, double radians) {
    final cosR = math.cos(radians);
    final sinR = math.sin(radians);
    return Offset(
      v.dx * cosR - v.dy * sinR,
      v.dx * sinR + v.dy * cosR,
    );
  }
}
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `flutter test test/core/utils/math_utils_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 9: Commit**

```bash
git add lib/core/utils/ test/core/utils/
git commit -m "Add seeded RNG and vector math utilities"
```

---

## Task 3: `CustomBall` Domain Model

**Files:**
- Create: `lib/features/ball_management/domain/custom_ball.dart`
- Test: `test/features/ball_management/domain/custom_ball_test.dart`

**Interfaces:**
- Consumes: nothing (leaf model).
- Produces: `CustomBall` class with fields `id: String`, `name: String`, `imageBytes: Uint8List?`, `assetPath: String?`, `primaryColor: Color`, `glowColor: Color`, `baseSpeed: double` (default 320.0), `mass: double` (default 1.0), and `copyWith(...)`.

- [ ] **Step 1: Write failing tests**

```dart
// test/features/ball_management/domain/custom_ball_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';

void main() {
  test('constructs with defaults', () {
    const ball = CustomBall(
      id: 'a',
      name: 'Test Ball',
      primaryColor: Colors.red,
      glowColor: Colors.pink,
    );
    expect(ball.baseSpeed, 320.0);
    expect(ball.mass, 1.0);
    expect(ball.imageBytes, isNull);
  });

  test('copyWith overrides only given fields and preserves id', () {
    const ball = CustomBall(
      id: 'a',
      name: 'Original',
      primaryColor: Colors.red,
      glowColor: Colors.pink,
    );
    final updated = ball.copyWith(name: 'Renamed', baseSpeed: 400.0);
    expect(updated.id, 'a');
    expect(updated.name, 'Renamed');
    expect(updated.baseSpeed, 400.0);
    expect(updated.primaryColor, Colors.red);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/ball_management/domain/custom_ball_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement `CustomBall`**

```dart
// lib/features/ball_management/domain/custom_ball.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';

class CustomBall {
  final String id;
  final String name;
  final Uint8List? imageBytes;
  final String? assetPath;
  final Color primaryColor;
  final Color glowColor;
  final double baseSpeed;
  final double mass;

  const CustomBall({
    required this.id,
    required this.name,
    this.imageBytes,
    this.assetPath,
    required this.primaryColor,
    required this.glowColor,
    this.baseSpeed = 320.0,
    this.mass = 1.0,
  });

  CustomBall copyWith({
    String? name,
    Uint8List? imageBytes,
    String? assetPath,
    Color? primaryColor,
    Color? glowColor,
    double? baseSpeed,
    double? mass,
  }) {
    return CustomBall(
      id: id,
      name: name ?? this.name,
      imageBytes: imageBytes ?? this.imageBytes,
      assetPath: assetPath ?? this.assetPath,
      primaryColor: primaryColor ?? this.primaryColor,
      glowColor: glowColor ?? this.glowColor,
      baseSpeed: baseSpeed ?? this.baseSpeed,
      mass: mass ?? this.mass,
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/ball_management/domain/custom_ball_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/ball_management/domain/custom_ball.dart test/features/ball_management/domain/custom_ball_test.dart
git commit -m "Add CustomBall domain model"
```

---

## Task 4: Ball Repository & Starter Presets

**Files:**
- Create: `lib/features/ball_management/domain/ball_repository.dart`
- Create: `lib/features/ball_management/data/local_ball_repository.dart`
- Test: `test/features/ball_management/data/local_ball_repository_test.dart`

**Interfaces:**
- Consumes: `CustomBall` (Task 3).
- Produces: abstract `BallRepository` with `List<CustomBall> getAll()`, `void add(CustomBall ball)`, `void remove(String id)`; `LocalBallRepository implements BallRepository` seeded with 4 presets (USA/Russia/Japan/Brazil using `AppColors` from Task 1).

- [ ] **Step 1: Write failing tests**

```dart
// test/features/ball_management/data/local_ball_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/ball_management/data/local_ball_repository.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';

void main() {
  test('seeds four starter presets', () {
    final repo = LocalBallRepository();
    final all = repo.getAll();
    expect(all.length, 4);
    expect(all.map((b) => b.name), containsAll(
      ['United States', 'Russia', 'Japan', 'Brazil'],
    ));
  });

  test('add appends a new ball', () {
    final repo = LocalBallRepository();
    const newBall = CustomBall(
      id: 'custom-1',
      name: 'Neon Dragon',
      primaryColor: Color(0xFFAA00FF),
      glowColor: Color(0xFFDD88FF),
    );
    repo.add(newBall);
    expect(repo.getAll().length, 5);
    expect(repo.getAll().last.name, 'Neon Dragon');
  });

  test('remove deletes ball by id', () {
    final repo = LocalBallRepository();
    final idToRemove = repo.getAll().first.id;
    repo.remove(idToRemove);
    expect(repo.getAll().length, 3);
    expect(repo.getAll().any((b) => b.id == idToRemove), isFalse);
  });
}
```

Note: this test file needs `import 'package:flutter/material.dart';` for the `Color` constant — add it alongside the other imports.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/ball_management/data/local_ball_repository_test.dart`
Expected: FAIL — files don't exist.

- [ ] **Step 3: Implement `BallRepository` interface**

```dart
// lib/features/ball_management/domain/ball_repository.dart
import 'custom_ball.dart';

abstract class BallRepository {
  List<CustomBall> getAll();
  void add(CustomBall ball);
  void remove(String id);
}
```

- [ ] **Step 4: Implement `LocalBallRepository` with presets**

```dart
// lib/features/ball_management/data/local_ball_repository.dart
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
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/ball_management/data/local_ball_repository_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/features/ball_management/domain/ball_repository.dart lib/features/ball_management/data/ test/features/ball_management/data/
git commit -m "Add ball repository with starter presets"
```

---

## Task 5: `SimulationBall` Model & Arena Physics Engine

**Files:**
- Create: `lib/features/arena_simulation/domain/simulation_ball.dart`
- Create: `lib/features/arena_simulation/domain/arena_physics_engine.dart`
- Test: `test/features/arena_simulation/domain/arena_physics_engine_test.dart`

**Interfaces:**
- Consumes: `CustomBall` (Task 3), `SeededRandom` (Task 2).
- Produces:
  - `SimulationBall` with mutable `position: Offset`, `velocity: Offset`, fields `config: CustomBall`, `radius: double`, `lineCount: int`, `cachedUiImage: ui.Image?`.
  - `ArenaPhysicsEngine(double arenaRadius, SeededRandom rng)` with:
    - `void resolveWallCollision(SimulationBall ball)`
    - `CollisionResult? resolveBallCollision(SimulationBall a, SimulationBall b)` returning `null` if not overlapping, else a `CollisionResult(Offset contactPoint, Offset normal, double relativeImpactSpeed)`.

- [ ] **Step 1: Write failing tests**

```dart
// test/features/arena_simulation/domain/arena_physics_engine_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/utils/seeded_random.dart';
import 'package:ballwars/features/arena_simulation/domain/arena_physics_engine.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_ball.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';

SimulationBall _ball({
  required Offset position,
  required Offset velocity,
  double radius = 20.0,
  double mass = 1.0,
}) {
  return SimulationBall(
    config: CustomBall(
      id: 'b',
      name: 'B',
      primaryColor: Colors.red,
      glowColor: Colors.pink,
      mass: mass,
    ),
    position: position,
    velocity: velocity,
    radius: radius,
    lineCount: 180,
  );
}

void main() {
  group('resolveWallCollision', () {
    test('reflects velocity and clamps position when past boundary', () {
      final engine = ArenaPhysicsEngine(100.0, SeededRandom(1));
      final ball = _ball(
        position: const Offset(95, 0),
        velocity: const Offset(10, 0),
        radius: 10.0,
      );
      engine.resolveWallCollision(ball);

      // radius from center must not exceed (arenaRadius - ballRadius)
      final dist = ball.position.distance;
      expect(dist, lessThanOrEqualTo(90.0 + 1e-6));
      // velocity x-component should have flipped sign (reflected inward)
      expect(ball.velocity.dx, lessThan(0));
    });

    test('does nothing when ball is well within boundary', () {
      final engine = ArenaPhysicsEngine(100.0, SeededRandom(1));
      final ball = _ball(
        position: const Offset(0, 0),
        velocity: const Offset(5, 5),
        radius: 10.0,
      );
      engine.resolveWallCollision(ball);
      expect(ball.position, const Offset(0, 0));
      expect(ball.velocity, const Offset(5, 5));
    });
  });

  group('resolveBallCollision', () {
    test('returns null when balls do not overlap', () {
      final engine = ArenaPhysicsEngine(200.0, SeededRandom(1));
      final a = _ball(position: const Offset(-100, 0), velocity: Offset.zero, radius: 10);
      final b = _ball(position: const Offset(100, 0), velocity: Offset.zero, radius: 10);
      expect(engine.resolveBallCollision(a, b), isNull);
    });

    test('separates overlapping balls and reflects velocities', () {
      final engine = ArenaPhysicsEngine(200.0, SeededRandom(1));
      final a = _ball(position: const Offset(-5, 0), velocity: const Offset(10, 0), radius: 10);
      final b = _ball(position: const Offset(5, 0), velocity: const Offset(-10, 0), radius: 10);

      final result = engine.resolveBallCollision(a, b);

      expect(result, isNotNull);
      // after separation, distance should be >= sum of radii
      final dist = (b.position - a.position).distance;
      expect(dist, greaterThanOrEqualTo(20.0 - 1e-6));
      // a was moving right into b, so it should now be moving left (or stopped)
      expect(a.velocity.dx, lessThanOrEqualTo(10.0));
      expect(result!.relativeImpactSpeed, greaterThan(0));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/arena_simulation/domain/arena_physics_engine_test.dart`
Expected: FAIL — files don't exist.

- [ ] **Step 3: Implement `SimulationBall`**

```dart
// lib/features/arena_simulation/domain/simulation_ball.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../ball_management/domain/custom_ball.dart';

class SimulationBall {
  final CustomBall config;
  Offset position;
  Offset velocity;
  double radius;
  int lineCount;
  ui.Image? cachedUiImage;

  SimulationBall({
    required this.config,
    required this.position,
    required this.velocity,
    required this.radius,
    required this.lineCount,
    this.cachedUiImage,
  });
}
```

- [ ] **Step 4: Implement `ArenaPhysicsEngine`**

```dart
// lib/features/arena_simulation/domain/arena_physics_engine.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/utils/seeded_random.dart';
import 'simulation_ball.dart';

class CollisionResult {
  final Offset contactPoint;
  final Offset normal;
  final double relativeImpactSpeed;

  const CollisionResult({
    required this.contactPoint,
    required this.normal,
    required this.relativeImpactSpeed,
  });
}

class ArenaPhysicsEngine {
  final double arenaRadius;
  final SeededRandom rng;

  static const double _jitterMaxRadians = 2 * math.pi / 180.0;

  ArenaPhysicsEngine(this.arenaRadius, this.rng);

  void resolveWallCollision(SimulationBall ball) {
    final d = ball.position.distance;
    final maxDist = arenaRadius - ball.radius;
    if (d < maxDist || d == 0) return;

    final normal = ball.position / d;
    final dot = ball.velocity.dx * normal.dx + ball.velocity.dy * normal.dy;
    var reflected = ball.velocity - normal * (2 * dot);

    final jitter = rng.nextDoubleRange(-_jitterMaxRadians, _jitterMaxRadians);
    final cosJ = math.cos(jitter);
    final sinJ = math.sin(jitter);
    reflected = Offset(
      reflected.dx * cosJ - reflected.dy * sinJ,
      reflected.dx * sinJ + reflected.dy * cosJ,
    );

    ball.velocity = reflected;
    ball.position = normal * maxDist;
  }

  CollisionResult? resolveBallCollision(SimulationBall a, SimulationBall b) {
    final delta = b.position - a.position;
    final dist = delta.distance;
    final minDist = a.radius + b.radius;
    if (dist >= minDist || dist == 0) return null;

    final normal = delta / dist;
    final overlap = 0.5 * (minDist - dist);
    a.position -= normal * overlap;
    b.position += normal * overlap;

    final relativeVelocity = a.velocity - b.velocity;
    final massA = a.config.mass;
    final massB = b.config.mass;
    final impulseScalar =
        (2 * (relativeVelocity.dx * normal.dx + relativeVelocity.dy * normal.dy)) /
            (massA + massB);

    a.velocity -= normal * (impulseScalar * massB);
    b.velocity += normal * (impulseScalar * massA);

    final relativeImpactSpeed =
        (relativeVelocity.dx * normal.dx + relativeVelocity.dy * normal.dy).abs();

    final contactPoint = a.position + normal * a.radius;

    return CollisionResult(
      contactPoint: contactPoint,
      normal: normal,
      relativeImpactSpeed: relativeImpactSpeed,
    );
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/arena_simulation/domain/arena_physics_engine_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/features/arena_simulation/domain/simulation_ball.dart lib/features/arena_simulation/domain/arena_physics_engine.dart test/features/arena_simulation/domain/arena_physics_engine_test.dart
git commit -m "Add SimulationBall model and arena physics engine"
```

---

## Task 6: Territory Engine — Sector Ownership, Line Stealing, Win Detection

**Files:**
- Create: `lib/features/arena_simulation/domain/territory_engine.dart`
- Test: `test/features/arena_simulation/domain/territory_engine_test.dart`

**Interfaces:**
- Consumes: `SeededRandom` (Task 2).
- Produces: `TerritoryEngine(int ballCount, SeededRandom rng)` with:
  - `List<String> sectorOwners` (360-length, values are ball ids).
  - `void initializeSplit(List<String> ballIds)`
  - `int countSectors(String ballId)`
  - `StealResult resolveSteal({required String winnerId, required String loserId})` returning `StealResult(int stolenCount)`, reassigning that many contiguous sectors from loser to winner (only sectors the loser currently owns; if the loser owns fewer than the rolled amount, steal all of them).
  - `bool isSlowMotion()` — true if any ball with >0 total sectors owned this match now owns `<= 15`.
  - `String? winnerId` — non-null once a ball reaches 360 sectors or all-but-one balls own 0.

- [ ] **Step 1: Write failing tests**

```dart
// test/features/arena_simulation/domain/territory_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/utils/seeded_random.dart';
import 'package:ballwars/features/arena_simulation/domain/territory_engine.dart';

void main() {
  group('initializeSplit', () {
    test('splits 360 sectors evenly among 2 balls', () {
      final engine = TerritoryEngine(2, SeededRandom(1));
      engine.initializeSplit(['a', 'b']);
      expect(engine.countSectors('a'), 180);
      expect(engine.countSectors('b'), 180);
      expect(engine.sectorOwners[0], 'a');
      expect(engine.sectorOwners[179], 'a');
      expect(engine.sectorOwners[180], 'b');
      expect(engine.sectorOwners[359], 'b');
    });

    test('splits 360 sectors evenly among 4 balls', () {
      final engine = TerritoryEngine(4, SeededRandom(1));
      engine.initializeSplit(['a', 'b', 'c', 'd']);
      expect(engine.countSectors('a'), 90);
      expect(engine.countSectors('b'), 90);
      expect(engine.countSectors('c'), 90);
      expect(engine.countSectors('d'), 90);
    });
  });

  group('resolveSteal', () {
    test('reassigns a clamped amount of sectors from loser to winner', () {
      final engine = TerritoryEngine(2, SeededRandom(5));
      engine.initializeSplit(['a', 'b']);
      final before = engine.countSectors('b');

      final result = engine.resolveSteal(winnerId: 'a', loserId: 'b');

      expect(result.stolenCount, inInclusiveRange(10, 75));
      expect(engine.countSectors('b'), before - result.stolenCount);
      expect(engine.countSectors('a'), 180 + result.stolenCount);
    });

    test('cannot steal more sectors than the loser owns', () {
      final engine = TerritoryEngine(2, SeededRandom(2));
      engine.initializeSplit(['a', 'b']);
      // Drain b down to 5 sectors via repeated steals.
      while (engine.countSectors('b') > 5) {
        engine.resolveSteal(winnerId: 'a', loserId: 'b');
      }
      final remaining = engine.countSectors('b');
      final result = engine.resolveSteal(winnerId: 'a', loserId: 'b');
      expect(result.stolenCount, remaining);
      expect(engine.countSectors('b'), 0);
    });
  });

  group('win + slow motion detection', () {
    test('winnerId is null while match is contested', () {
      final engine = TerritoryEngine(2, SeededRandom(1));
      engine.initializeSplit(['a', 'b']);
      expect(engine.winnerId, isNull);
    });

    test('winnerId is set once a ball reaches 360 sectors', () {
      final engine = TerritoryEngine(2, SeededRandom(3));
      engine.initializeSplit(['a', 'b']);
      while (engine.countSectors('b') > 0) {
        engine.resolveSteal(winnerId: 'a', loserId: 'b');
      }
      expect(engine.countSectors('a'), 360);
      expect(engine.winnerId, 'a');
    });

    test('isSlowMotion becomes true once a ball drops to 15 or fewer sectors', () {
      final engine = TerritoryEngine(2, SeededRandom(4));
      engine.initializeSplit(['a', 'b']);
      expect(engine.isSlowMotion(), isFalse);
      while (engine.countSectors('b') > 15) {
        engine.resolveSteal(winnerId: 'a', loserId: 'b');
      }
      expect(engine.isSlowMotion(), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/arena_simulation/domain/territory_engine_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement `TerritoryEngine`**

```dart
// lib/features/arena_simulation/domain/territory_engine.dart
import '../../../core/utils/seeded_random.dart';

class StealResult {
  final int stolenCount;
  const StealResult(this.stolenCount);
}

class TerritoryEngine {
  static const int totalSectors = 360;

  final int ballCount;
  final SeededRandom rng;
  final List<String> sectorOwners = List.filled(totalSectors, '');

  String? winnerId;

  TerritoryEngine(this.ballCount, this.rng);

  void initializeSplit(List<String> ballIds) {
    final perBall = totalSectors ~/ ballIds.length;
    for (var i = 0; i < ballIds.length; i++) {
      final start = i * perBall;
      final end = (i == ballIds.length - 1) ? totalSectors : start + perBall;
      for (var s = start; s < end; s++) {
        sectorOwners[s] = ballIds[i];
      }
    }
    winnerId = null;
  }

  int countSectors(String ballId) =>
      sectorOwners.where((owner) => owner == ballId).length;

  StealResult resolveSteal({required String winnerId, required String loserId}) {
    final loserSectorIndices = <int>[
      for (var i = 0; i < totalSectors; i++)
        if (sectorOwners[i] == loserId) i,
    ];

    final rolled = 20 + rng.nextInt(26); // 20..45
    final clamped = rolled.clamp(10, 75);
    final stealAmount = clamped > loserSectorIndices.length
        ? loserSectorIndices.length
        : clamped;

    for (var i = 0; i < stealAmount; i++) {
      sectorOwners[loserSectorIndices[i]] = winnerId;
    }

    _checkWinCondition();

    return StealResult(stealAmount);
  }

  bool isSlowMotion() {
    final ownerCounts = <String, int>{};
    for (final owner in sectorOwners) {
      if (owner.isEmpty) continue;
      ownerCounts[owner] = (ownerCounts[owner] ?? 0) + 1;
    }
    return ownerCounts.values.any((count) => count > 0 && count <= 15);
  }

  void _checkWinCondition() {
    final ownerCounts = <String, int>{};
    for (final owner in sectorOwners) {
      if (owner.isEmpty) continue;
      ownerCounts[owner] = (ownerCounts[owner] ?? 0) + 1;
    }
    for (final entry in ownerCounts.entries) {
      if (entry.value >= totalSectors) {
        winnerId = entry.key;
        return;
      }
    }
    final activeOwners = ownerCounts.entries.where((e) => e.value > 0).toList();
    if (activeOwners.length == 1) {
      winnerId = activeOwners.first.key;
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/arena_simulation/domain/territory_engine_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/arena_simulation/domain/territory_engine.dart test/features/arena_simulation/domain/territory_engine_test.dart
git commit -m "Add territory engine with line stealing and win detection"
```

---

## Task 7: Particle System & Floating Text

**Files:**
- Create: `lib/features/arena_simulation/domain/particle_system.dart`
- Create: `lib/features/arena_simulation/domain/floating_text.dart`
- Test: `test/features/arena_simulation/domain/particle_system_test.dart`

**Interfaces:**
- Consumes: `SeededRandom` (Task 2).
- Produces:
  - `Particle` (mutable `position: Offset`, `velocity: Offset`, `age: double`, `lifespan: double`, `color: Color`) with `bool get isExpired => age >= lifespan`.
  - `ParticleSystem` with `void spawnBurst({required Offset origin, required Offset normal, required Color color, required SeededRandom rng})` (spawns 20-30 particles spraying around `normal`), `void update(double dt)` (advances age/position, removes expired), `List<Particle> get particles`.
  - `FloatingText` (mutable `position: Offset`, `age: double`, `text: String`, `color: Color`) with fixed `lifespan = 1.2` seconds and `double get opacity` (1.0 fading to 0.0 linearly over lifespan).
  - `FloatingTextManager` with `void spawn(Offset position, String text, Color color)`, `void update(double dt)`, `List<FloatingText> get items`.

- [ ] **Step 1: Write failing tests**

```dart
// test/features/arena_simulation/domain/particle_system_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/utils/seeded_random.dart';
import 'package:ballwars/features/arena_simulation/domain/particle_system.dart';
import 'package:ballwars/features/arena_simulation/domain/floating_text.dart';

void main() {
  group('ParticleSystem', () {
    test('spawnBurst adds 20 to 30 particles', () {
      final system = ParticleSystem();
      system.spawnBurst(
        origin: Offset.zero,
        normal: const Offset(1, 0),
        color: Colors.red,
        rng: SeededRandom(1),
      );
      expect(system.particles.length, inInclusiveRange(20, 30));
    });

    test('update ages particles and removes expired ones', () {
      final system = ParticleSystem();
      system.spawnBurst(
        origin: Offset.zero,
        normal: const Offset(1, 0),
        color: Colors.red,
        rng: SeededRandom(1),
      );
      final countBefore = system.particles.length;
      system.update(0.1);
      expect(system.particles.length, lessThanOrEqualTo(countBefore));
      // Advance well past any plausible lifespan.
      for (var i = 0; i < 50; i++) {
        system.update(0.1);
      }
      expect(system.particles, isEmpty);
    });
  });

  group('FloatingTextManager', () {
    test('spawn adds a floating text item with full opacity', () {
      final manager = FloatingTextManager();
      manager.spawn(Offset.zero, '+35 LINES', Colors.green);
      expect(manager.items.length, 1);
      expect(manager.items.first.opacity, closeTo(1.0, 1e-9));
    });

    test('update fades and removes expired items', () {
      final manager = FloatingTextManager();
      manager.spawn(Offset.zero, '+35 LINES', Colors.green);
      manager.update(0.6);
      expect(manager.items.first.opacity, closeTo(0.5, 0.05));
      manager.update(1.0);
      expect(manager.items, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/arena_simulation/domain/particle_system_test.dart`
Expected: FAIL — files don't exist.

- [ ] **Step 3: Implement `floating_text.dart`**

```dart
// lib/features/arena_simulation/domain/floating_text.dart
import 'package:flutter/material.dart';

class FloatingText {
  static const double lifespan = 1.2;

  Offset position;
  double age;
  final String text;
  final Color color;

  FloatingText({
    required this.position,
    required this.text,
    required this.color,
    this.age = 0.0,
  });

  bool get isExpired => age >= lifespan;

  double get opacity => (1.0 - (age / lifespan)).clamp(0.0, 1.0);
}

class FloatingTextManager {
  final List<FloatingText> _items = [];

  List<FloatingText> get items => List.unmodifiable(_items);

  void spawn(Offset position, String text, Color color) {
    _items.add(FloatingText(position: position, text: text, color: color));
  }

  void update(double dt) {
    for (final item in _items) {
      item.age += dt;
      item.position = item.position.translate(0, -20 * dt);
    }
    _items.removeWhere((item) => item.isExpired);
  }
}
```

- [ ] **Step 4: Implement `particle_system.dart`**

```dart
// lib/features/arena_simulation/domain/particle_system.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/utils/seeded_random.dart';

class Particle {
  Offset position;
  Offset velocity;
  double age;
  final double lifespan;
  final Color color;

  Particle({
    required this.position,
    required this.velocity,
    required this.lifespan,
    required this.color,
    this.age = 0.0,
  });

  bool get isExpired => age >= lifespan;
}

class ParticleSystem {
  final List<Particle> _particles = [];

  List<Particle> get particles => List.unmodifiable(_particles);

  void spawnBurst({
    required Offset origin,
    required Offset normal,
    required Color color,
    required SeededRandom rng,
  }) {
    final count = 20 + rng.nextInt(11); // 20..30
    final baseAngle = math.atan2(normal.dy, normal.dx);

    for (var i = 0; i < count; i++) {
      final spread = rng.nextDoubleRange(-math.pi / 3, math.pi / 3);
      final angle = baseAngle + spread;
      final speed = rng.nextDoubleRange(60.0, 180.0);
      final velocity = Offset(math.cos(angle), math.sin(angle)) * speed;
      final lifespan = rng.nextDoubleRange(0.4, 0.9);

      _particles.add(Particle(
        position: origin,
        velocity: velocity,
        lifespan: lifespan,
        color: color,
      ));
    }
  }

  void update(double dt) {
    for (final particle in _particles) {
      particle.age += dt;
      particle.position += particle.velocity * dt;
    }
    _particles.removeWhere((p) => p.isExpired);
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/arena_simulation/domain/particle_system_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/features/arena_simulation/domain/particle_system.dart lib/features/arena_simulation/domain/floating_text.dart test/features/arena_simulation/domain/particle_system_test.dart
git commit -m "Add particle system and floating text overlays"
```

---

## Task 8: Match Simulation Controller (Fixed-Timestep Loop)

**Files:**
- Create: `lib/features/arena_simulation/domain/simulation_state.dart`
- Create: `lib/features/arena_simulation/application/match_simulation_controller.dart`
- Test: `test/features/arena_simulation/application/match_simulation_controller_test.dart`

**Interfaces:**
- Consumes: `SimulationBall`/`ArenaPhysicsEngine` (Task 5), `TerritoryEngine` (Task 6), `ParticleSystem`/`FloatingTextManager` (Task 7), `CustomBall` (Task 3), `SeededRandom` (Task 2).
- Produces:
  - `MatchStatus` enum: `running, slowMotion, finished`.
  - `SimulationState` (immutable snapshot: `List<SimulationBall> balls`, `TerritoryEngine territory`, `ParticleSystem particles`, `FloatingTextManager floatingTexts`, `MatchStatus status`, `String? winnerId`).
  - `MatchSimulationController(List<CustomBall> contestants, {required double arenaRadius, int? seed})` with:
    - `SimulationState get state`
    - `void tick(double realDeltaSeconds)` — accumulates into fixed 1/60s steps and advances the sim.
    - `static const double fixedTimestep = 1 / 60;`

- [ ] **Step 1: Write failing tests**

```dart
// test/features/arena_simulation/application/match_simulation_controller_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_state.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';

List<CustomBall> _twoBalls() => const [
      CustomBall(id: 'a', name: 'A', primaryColor: Colors.red, glowColor: Colors.pink),
      CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan),
    ];

void main() {
  test('initializes with balls placed inside the arena and even territory split', () {
    final controller = MatchSimulationController(_twoBalls(), arenaRadius: 260.0, seed: 1);
    final state = controller.state;

    expect(state.balls.length, 2);
    for (final ball in state.balls) {
      expect(ball.position.distance, lessThanOrEqualTo(260.0));
    }
    expect(state.territory.countSectors('a'), 180);
    expect(state.territory.countSectors('b'), 180);
    expect(state.status, MatchStatus.running);
  });

  test('same seed and contestants produce identical state after N ticks (determinism)', () {
    final controllerA = MatchSimulationController(_twoBalls(), arenaRadius: 260.0, seed: 99);
    final controllerB = MatchSimulationController(_twoBalls(), arenaRadius: 260.0, seed: 99);

    for (var i = 0; i < 300; i++) {
      controllerA.tick(1 / 60);
      controllerB.tick(1 / 60);
    }

    final stateA = controllerA.state;
    final stateB = controllerB.state;

    expect(stateA.territory.sectorOwners, equals(stateB.territory.sectorOwners));
    for (var i = 0; i < stateA.balls.length; i++) {
      expect(stateA.balls[i].position, equals(stateB.balls[i].position));
      expect(stateA.balls[i].velocity, equals(stateB.balls[i].velocity));
    }
  });

  test('tick accumulates partial real time into fixed steps without drifting immediately', () {
    final controller = MatchSimulationController(_twoBalls(), arenaRadius: 260.0, seed: 5);
    final before = controller.state.balls.first.position;
    // Less than one fixed timestep (1/60 ~= 0.01667) should not advance physics yet.
    controller.tick(0.005);
    final after = controller.state.balls.first.position;
    expect(after, before);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/arena_simulation/application/match_simulation_controller_test.dart`
Expected: FAIL — files don't exist.

- [ ] **Step 3: Implement `simulation_state.dart`**

```dart
// lib/features/arena_simulation/domain/simulation_state.dart
import 'floating_text.dart';
import 'particle_system.dart';
import 'simulation_ball.dart';
import 'territory_engine.dart';

enum MatchStatus { running, slowMotion, finished }

class SimulationState {
  final List<SimulationBall> balls;
  final TerritoryEngine territory;
  final ParticleSystem particles;
  final FloatingTextManager floatingTexts;
  final MatchStatus status;
  final String? winnerId;

  const SimulationState({
    required this.balls,
    required this.territory,
    required this.particles,
    required this.floatingTexts,
    required this.status,
    required this.winnerId,
  });
}
```

- [ ] **Step 4: Implement `match_simulation_controller.dart`**

```dart
// lib/features/arena_simulation/application/match_simulation_controller.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/utils/seeded_random.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../domain/arena_physics_engine.dart';
import '../domain/floating_text.dart';
import '../domain/particle_system.dart';
import '../domain/simulation_ball.dart';
import '../domain/simulation_state.dart';
import '../domain/territory_engine.dart';

class MatchSimulationController {
  static const double fixedTimestep = 1 / 60;

  final double arenaRadius;
  late final SeededRandom _rng;
  late final ArenaPhysicsEngine _physics;
  late final TerritoryEngine _territory;
  final ParticleSystem _particles = ParticleSystem();
  final FloatingTextManager _floatingTexts = FloatingTextManager();
  late final List<SimulationBall> _balls;

  double _accumulator = 0.0;
  MatchStatus _status = MatchStatus.running;

  MatchSimulationController(
    List<CustomBall> contestants, {
    required this.arenaRadius,
    int? seed,
  }) {
    final resolvedSeed = seed ?? DateTime.now().millisecondsSinceEpoch;
    _rng = SeededRandom(resolvedSeed);
    _physics = ArenaPhysicsEngine(arenaRadius, _rng);
    _territory = TerritoryEngine(contestants.length, _rng);
    _territory.initializeSplit(contestants.map((c) => c.id).toList());

    final ballRadius = arenaRadius * 0.08;
    _balls = List.generate(contestants.length, (i) {
      final angle = (2 * math.pi / contestants.length) * i;
      final startRadius = arenaRadius * 0.4;
      final position = Offset(
        math.cos(angle) * startRadius,
        math.sin(angle) * startRadius,
      );
      final speed = contestants[i].baseSpeed;
      final velocity = Offset(math.cos(angle + math.pi / 2), math.sin(angle + math.pi / 2)) * speed;
      return SimulationBall(
        config: contestants[i],
        position: position,
        velocity: velocity,
        radius: ballRadius,
        lineCount: TerritoryEngine.totalSectors ~/ contestants.length,
      );
    });
  }

  SimulationState get state => SimulationState(
        balls: _balls,
        territory: _territory,
        particles: _particles,
        floatingTexts: _floatingTexts,
        status: _status,
        winnerId: _territory.winnerId,
      );

  void tick(double realDeltaSeconds) {
    if (_status == MatchStatus.finished) return;

    final timeScale = _status == MatchStatus.slowMotion ? 0.25 : 1.0;
    _accumulator += realDeltaSeconds * timeScale;

    while (_accumulator >= fixedTimestep) {
      _stepPhysics(fixedTimestep);
      _accumulator -= fixedTimestep;
    }

    _particles.update(realDeltaSeconds);
    _floatingTexts.update(realDeltaSeconds);
  }

  void _stepPhysics(double dt) {
    for (final ball in _balls) {
      ball.position += ball.velocity * dt;
      _physics.resolveWallCollision(ball);
    }

    for (var i = 0; i < _balls.length; i++) {
      for (var j = i + 1; j < _balls.length; j++) {
        final result = _physics.resolveBallCollision(_balls[i], _balls[j]);
        if (result != null) {
          _handleCollision(_balls[i], _balls[j], result);
        }
      }
    }

    for (final ball in _balls) {
      ball.lineCount = _territory.countSectors(ball.config.id);
    }

    if (_territory.winnerId != null) {
      _status = MatchStatus.finished;
    } else if (_territory.isSlowMotion()) {
      _status = MatchStatus.slowMotion;
    }
  }

  void _handleCollision(SimulationBall a, SimulationBall b, CollisionResult result) {
    final aFaster = a.velocity.distance >= b.velocity.distance;
    final winner = aFaster ? a : b;
    final loser = aFaster ? b : a;

    final stealResult = _territory.resolveSteal(
      winnerId: winner.config.id,
      loserId: loser.config.id,
    );

    if (stealResult.stolenCount > 0) {
      _floatingTexts.spawn(
        winner.position,
        '+${stealResult.stolenCount} LINES',
        winner.config.primaryColor,
      );
    }

    _particles.spawnBurst(
      origin: result.contactPoint,
      normal: result.normal,
      color: winner.config.primaryColor,
      rng: _rng,
    );
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/arena_simulation/application/match_simulation_controller_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Run the full test suite**

Run: `flutter test`
Expected: PASS (all tests across all files so far).

- [ ] **Step 7: Commit**

```bash
git add lib/features/arena_simulation/domain/simulation_state.dart lib/features/arena_simulation/application/ test/features/arena_simulation/application/
git commit -m "Add match simulation controller with fixed-timestep loop"
```

---

## Task 9: Core Widgets — Neon Button & Glowing Card

**Files:**
- Create: `lib/core/widgets/neon_button.dart`
- Create: `lib/core/widgets/glowing_card.dart`
- Test: `test/core/widgets/neon_button_test.dart`

**Interfaces:**
- Consumes: `AppColors` (Task 1).
- Produces: `NeonButton({required String label, required VoidCallback onPressed, Color color = AppColors.russiaPrimary})` (a `StatelessWidget`, min size 44x44), `GlowingCard({required Widget child, Color glowColor = AppColors.russiaGlow})` (a `StatelessWidget` wrapping `child` in a glow-shadowed container).

- [ ] **Step 1: Write a failing widget test**

```dart
// test/core/widgets/neon_button_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/widgets/neon_button.dart';

void main() {
  testWidgets('NeonButton renders label and triggers onPressed', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NeonButton(
          label: 'START BATTLE',
          onPressed: () => tapped = true,
        ),
      ),
    ));

    expect(find.text('START BATTLE'), findsOneWidget);

    final buttonSize = tester.getSize(find.byType(NeonButton));
    expect(buttonSize.width, greaterThanOrEqualTo(44));
    expect(buttonSize.height, greaterThanOrEqualTo(44));

    await tester.tap(find.byType(NeonButton));
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/widgets/neon_button_test.dart`
Expected: FAIL — `neon_button.dart` doesn't exist.

- [ ] **Step 3: Implement `NeonButton`**

```dart
// lib/core/widgets/neon_button.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class NeonButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color color;

  const NeonButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.russiaPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.6), blurRadius: 16, spreadRadius: 1),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: color,
            side: BorderSide(color: color, width: 2),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: color),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/widgets/neon_button_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Implement `GlowingCard` (no dedicated test — pure decoration wrapper, covered visually in Task 11)**

```dart
// lib/core/widgets/glowing_card.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GlowingCard extends StatelessWidget {
  final Widget child;
  final Color glowColor;

  const GlowingCard({
    super.key,
    required this.child,
    this.glowColor = AppColors.russiaGlow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: glowColor.withOpacity(0.7), width: 1.5),
        boxShadow: [
          BoxShadow(color: glowColor.withOpacity(0.35), blurRadius: 20, spreadRadius: 2),
        ],
      ),
      child: child,
    );
  }
}
```

- [ ] **Step 6: Commit**

```bash
git add lib/core/widgets/ test/core/widgets/
git commit -m "Add neon button and glowing card core widgets"
```

---

## Task 10: Ball Editor Dialog — Preview & Image Upload

**Files:**
- Create: `lib/features/ball_management/presentation/widgets/circular_ball_preview.dart`
- Create: `lib/features/ball_management/presentation/ball_editor_dialog.dart`
- Test: `test/features/ball_management/presentation/widgets/circular_ball_preview_test.dart`

**Interfaces:**
- Consumes: `CustomBall` (Task 3), `NeonButton`/`GlowingCard` (Task 9).
- Produces:
  - `CircularBallPreview({required CustomBall ball, double size = 96})` — a `StatelessWidget` rendering a glowing circle with either the ball's image or its initials.
  - `BallEditorDialog({CustomBall? existing, required void Function(CustomBall) onSave})` — a `StatelessWidget`/`StatefulWidget` shown via `showDialog`, with name field, color pickers (using `showDialog` + a simple preset color grid — no external color-picker package), an image-upload button using `file_picker`, and a live `CircularBallPreview`.

- [ ] **Step 1: Write a failing widget test for the preview**

```dart
// test/features/ball_management/presentation/widgets/circular_ball_preview_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/ball_management/presentation/widgets/circular_ball_preview.dart';

void main() {
  testWidgets('shows initials when no image is set', (tester) async {
    const ball = CustomBall(
      id: 'x',
      name: 'Neon Dragon',
      primaryColor: Colors.purple,
      glowColor: Colors.pink,
    );

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: CircularBallPreview(ball: ball)),
    ));

    expect(find.text('ND'), findsOneWidget);
  });

  testWidgets('renders at the requested size', (tester) async {
    const ball = CustomBall(
      id: 'x',
      name: 'A',
      primaryColor: Colors.purple,
      glowColor: Colors.pink,
    );

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: CircularBallPreview(ball: ball, size: 120)),
    ));

    final size = tester.getSize(find.byType(CircularBallPreview));
    expect(size.width, 120);
    expect(size.height, 120);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/ball_management/presentation/widgets/circular_ball_preview_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement `CircularBallPreview`**

```dart
// lib/features/ball_management/presentation/widgets/circular_ball_preview.dart
import 'package:flutter/material.dart';
import '../../domain/custom_ball.dart';

class CircularBallPreview extends StatelessWidget {
  final CustomBall ball;
  final double size;

  const CircularBallPreview({super.key, required this.ball, this.size = 96});

  String get _initials {
    final parts = ball.name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ball.glowColor, width: 3),
        boxShadow: [
          BoxShadow(color: ball.glowColor.withOpacity(0.7), blurRadius: size * 0.25, spreadRadius: 2),
        ],
      ),
      child: ClipOval(
        child: ball.imageBytes != null
            ? Image.memory(ball.imageBytes!, fit: BoxFit.cover)
            : Container(
                color: ball.primaryColor,
                alignment: Alignment.center,
                child: Text(
                  _initials,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: size * 0.32,
                  ),
                ),
              ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/ball_management/presentation/widgets/circular_ball_preview_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Implement `BallEditorDialog` (manual verification — see Task 11)**

```dart
// lib/features/ball_management/presentation/ball_editor_dialog.dart
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/neon_button.dart';
import '../domain/custom_ball.dart';
import 'widgets/circular_ball_preview.dart';

const List<Color> kNeonColorPresets = [
  Color(0xFF28E21B),
  Color(0xFF00E5FF),
  Color(0xFFFF1744),
  Color(0xFFFFEA00),
  Color(0xFFAA00FF),
  Color(0xFFFF6D00),
];

class BallEditorDialog extends StatefulWidget {
  final CustomBall? existing;
  final void Function(CustomBall) onSave;

  const BallEditorDialog({super.key, this.existing, required this.onSave});

  @override
  State<BallEditorDialog> createState() => _BallEditorDialogState();
}

class _BallEditorDialogState extends State<BallEditorDialog> {
  late final TextEditingController _nameController;
  late Color _primaryColor;
  late Color _glowColor;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _primaryColor = widget.existing?.primaryColor ?? kNeonColorPresets[0];
    _glowColor = widget.existing?.glowColor ?? kNeonColorPresets[1];
    _imageBytes = widget.existing?.imageBytes;
  }

  CustomBall get _previewBall => CustomBall(
        id: widget.existing?.id ?? 'preview',
        name: _nameController.text.isEmpty ? 'New Ball' : _nameController.text,
        imageBytes: _imageBytes,
        primaryColor: _primaryColor,
        glowColor: _glowColor,
      );

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes != null) {
      setState(() => _imageBytes = bytes);
    }
  }

  Widget _colorPresetRow(Color selected, ValueChanged<Color> onSelect) {
    return Wrap(
      spacing: 8,
      children: kNeonColorPresets.map((c) {
        final isSelected = c.value == selected.value;
        return GestureDetector(
          onTap: () => onSelect(c),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0A0E17),
      title: const Text('Create Ball'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularBallPreview(ball: _previewBall, size: 96),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: const Text('Primary Color')),
            _colorPresetRow(_primaryColor, (c) => setState(() => _primaryColor = c)),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: const Text('Glow Color')),
            _colorPresetRow(_glowColor, (c) => setState(() => _glowColor = c)),
            const SizedBox(height: 12),
            NeonButton(label: 'UPLOAD IMAGE', onPressed: _pickImage),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        NeonButton(
          label: 'SAVE',
          onPressed: () {
            if (_nameController.text.trim().isEmpty) return;
            widget.onSave(CustomBall(
              id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
              name: _nameController.text.trim(),
              imageBytes: _imageBytes,
              primaryColor: _primaryColor,
              glowColor: _glowColor,
            ));
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
```

- [ ] **Step 6: Commit**

```bash
git add lib/features/ball_management/presentation/ test/features/ball_management/presentation/
git commit -m "Add ball editor dialog with image upload and circular preview"
```

---

## Task 11: Ball Library Screen

**Files:**
- Create: `lib/features/ball_management/presentation/ball_library_screen.dart`
- Test: `test/features/ball_management/presentation/ball_library_screen_test.dart`

**Interfaces:**
- Consumes: `LocalBallRepository`/`BallRepository` (Task 4), `CircularBallPreview` (Task 10), `BallEditorDialog` (Task 10), `NeonButton` (Task 9).
- Produces: `BallLibraryScreen({required BallRepository repository})` — a `StatefulWidget` showing a grid of `CircularBallPreview` + name, a "Create New Ball" `NeonButton` that opens `BallEditorDialog`, and returns the list of currently selected ball ids via an `onSelectionChanged` callback (used by Task 13's setup screen). To keep this screen usable standalone in this task, selection support is optional (`bool selectable = false`, `void Function(List<String>)? onSelectionChanged`).

- [ ] **Step 1: Write a failing widget test**

```dart
// test/features/ball_management/presentation/ball_library_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/ball_management/data/local_ball_repository.dart';
import 'package:ballwars/features/ball_management/presentation/ball_library_screen.dart';

void main() {
  testWidgets('renders all balls from the repository', (tester) async {
    final repo = LocalBallRepository();
    await tester.pumpWidget(MaterialApp(
      home: BallLibraryScreen(repository: repo),
    ));

    expect(find.text('United States'), findsOneWidget);
    expect(find.text('Russia'), findsOneWidget);
    expect(find.text('Japan'), findsOneWidget);
    expect(find.text('Brazil'), findsOneWidget);
  });

  testWidgets('opens the ball editor dialog on Create New Ball tap', (tester) async {
    final repo = LocalBallRepository();
    await tester.pumpWidget(MaterialApp(
      home: BallLibraryScreen(repository: repo),
    ));

    await tester.tap(find.text('CREATE NEW BALL'));
    await tester.pumpAndSettle();

    expect(find.text('Create Ball'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/ball_management/presentation/ball_library_screen_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement `BallLibraryScreen`**

```dart
// lib/features/ball_management/presentation/ball_library_screen.dart
import 'package:flutter/material.dart';
import '../../../core/widgets/neon_button.dart';
import '../domain/ball_repository.dart';
import '../domain/custom_ball.dart';
import 'ball_editor_dialog.dart';
import 'widgets/circular_ball_preview.dart';

class BallLibraryScreen extends StatefulWidget {
  final BallRepository repository;
  final bool selectable;
  final void Function(List<String>)? onSelectionChanged;

  const BallLibraryScreen({
    super.key,
    required this.repository,
    this.selectable = false,
    this.onSelectionChanged,
  });

  @override
  State<BallLibraryScreen> createState() => _BallLibraryScreenState();
}

class _BallLibraryScreenState extends State<BallLibraryScreen> {
  final Set<String> _selectedIds = {};

  void _toggleSelection(CustomBall ball) {
    if (!widget.selectable) return;
    setState(() {
      if (_selectedIds.contains(ball.id)) {
        _selectedIds.remove(ball.id);
      } else {
        _selectedIds.add(ball.id);
      }
    });
    widget.onSelectionChanged?.call(_selectedIds.toList());
  }

  void _openEditor() {
    showDialog(
      context: context,
      builder: (_) => BallEditorDialog(
        onSave: (ball) => setState(() => widget.repository.add(ball)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final balls = widget.repository.getAll();

    return Scaffold(
      appBar: AppBar(title: const Text('Ball Library')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            NeonButton(label: 'CREATE NEW BALL', onPressed: _openEditor),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                ),
                itemCount: balls.length,
                itemBuilder: (context, index) {
                  final ball = balls[index];
                  final isSelected = _selectedIds.contains(ball.id);
                  return GestureDetector(
                    onTap: () => _toggleSelection(ball),
                    child: Column(
                      children: [
                        Opacity(
                          opacity: !widget.selectable || isSelected ? 1.0 : 0.5,
                          child: CircularBallPreview(ball: ball, size: 72),
                        ),
                        const SizedBox(height: 8),
                        Text(ball.name, textAlign: TextAlign.center),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/ball_management/presentation/ball_library_screen_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/ball_management/presentation/ball_library_screen.dart test/features/ball_management/presentation/ball_library_screen_test.dart
git commit -m "Add ball library screen with creation flow"
```

---

## Task 12: Match Config Domain & Match Setup Screen

**Files:**
- Create: `lib/features/match_setup/domain/match_config.dart`
- Create: `lib/features/match_setup/presentation/widgets/ball_selection_carousel.dart`
- Create: `lib/features/match_setup/presentation/match_setup_screen.dart`
- Test: `test/features/match_setup/presentation/match_setup_screen_test.dart`

**Interfaces:**
- Consumes: `CustomBall`/`BallRepository` (Tasks 3-4), `NeonButton`/`CircularBallPreview` (Tasks 9-10).
- Produces:
  - `MatchConfig` (`List<CustomBall> contestants`, `double speedMultiplier`, `WinCondition winCondition`), `WinCondition` enum `{domination, timeAttack}`.
  - `BallSelectionCarousel({required List<CustomBall> availableBalls, required Set<String> selectedIds, required ValueChanged<String> onToggle})` — horizontal scroll of selectable `CircularBallPreview`s.
  - `MatchSetupScreen({required BallRepository repository, required void Function(MatchConfig) onStartBattle})` — lets the user pick 2-4 balls, a speed slider (0.5/1/2/4x), a win-condition selector, and a "START BATTLE" `NeonButton` (disabled until 2-4 balls are selected).

- [ ] **Step 1: Write a failing widget test**

```dart
// test/features/match_setup/presentation/match_setup_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/ball_management/data/local_ball_repository.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/match_setup/presentation/match_setup_screen.dart';

void main() {
  testWidgets('START BATTLE is disabled until at least 2 balls are selected', (tester) async {
    final repo = LocalBallRepository();
    MatchConfig? startedConfig;

    await tester.pumpWidget(MaterialApp(
      home: MatchSetupScreen(
        repository: repo,
        onStartBattle: (config) => startedConfig = config,
      ),
    ));

    await tester.tap(find.text('START BATTLE'));
    await tester.pump();
    expect(startedConfig, isNull);

    await tester.tap(find.text('United States'));
    await tester.tap(find.text('Russia'));
    await tester.pump();

    await tester.tap(find.text('START BATTLE'));
    await tester.pump();

    expect(startedConfig, isNotNull);
    expect(startedConfig!.contestants.length, 2);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/match_setup/presentation/match_setup_screen_test.dart`
Expected: FAIL — files don't exist.

- [ ] **Step 3: Implement `MatchConfig`**

```dart
// lib/features/match_setup/domain/match_config.dart
import '../../ball_management/domain/custom_ball.dart';

enum WinCondition { domination, timeAttack }

class MatchConfig {
  final List<CustomBall> contestants;
  final double speedMultiplier;
  final WinCondition winCondition;

  const MatchConfig({
    required this.contestants,
    this.speedMultiplier = 1.0,
    this.winCondition = WinCondition.domination,
  });
}
```

- [ ] **Step 4: Implement `BallSelectionCarousel`**

```dart
// lib/features/match_setup/presentation/widgets/ball_selection_carousel.dart
import 'package:flutter/material.dart';
import '../../../ball_management/domain/custom_ball.dart';
import '../../../ball_management/presentation/widgets/circular_ball_preview.dart';

class BallSelectionCarousel extends StatelessWidget {
  final List<CustomBall> availableBalls;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  const BallSelectionCarousel({
    super.key,
    required this.availableBalls,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: availableBalls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final ball = availableBalls[index];
          final isSelected = selectedIds.contains(ball.id);
          return GestureDetector(
            onTap: () => onToggle(ball.id),
            child: Column(
              children: [
                Opacity(
                  opacity: isSelected ? 1.0 : 0.4,
                  child: CircularBallPreview(ball: ball, size: 72),
                ),
                const SizedBox(height: 4),
                Text(ball.name, style: const TextStyle(fontSize: 12)),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 5: Implement `MatchSetupScreen`**

```dart
// lib/features/match_setup/presentation/match_setup_screen.dart
import 'package:flutter/material.dart';
import '../../../core/widgets/neon_button.dart';
import '../../ball_management/domain/ball_repository.dart';
import '../domain/match_config.dart';
import 'widgets/ball_selection_carousel.dart';

class MatchSetupScreen extends StatefulWidget {
  final BallRepository repository;
  final void Function(MatchConfig) onStartBattle;

  const MatchSetupScreen({
    super.key,
    required this.repository,
    required this.onStartBattle,
  });

  @override
  State<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends State<MatchSetupScreen> {
  final Set<String> _selectedIds = {};
  double _speedMultiplier = 1.0;
  WinCondition _winCondition = WinCondition.domination;

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else if (_selectedIds.length < 4) {
        _selectedIds.add(id);
      }
    });
  }

  bool get _canStart => _selectedIds.length >= 2 && _selectedIds.length <= 4;

  void _start() {
    if (!_canStart) return;
    final allBalls = widget.repository.getAll();
    final contestants = allBalls.where((b) => _selectedIds.contains(b.id)).toList();
    widget.onStartBattle(MatchConfig(
      contestants: contestants,
      speedMultiplier: _speedMultiplier,
      winCondition: _winCondition,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final balls = widget.repository.getAll();

    return Scaffold(
      appBar: AppBar(title: const Text('Match Setup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select 2-4 Balls'),
            const SizedBox(height: 8),
            BallSelectionCarousel(
              availableBalls: balls,
              selectedIds: _selectedIds,
              onToggle: _toggle,
            ),
            const SizedBox(height: 24),
            const Text('Speed'),
            Slider(
              value: _speedMultiplier,
              min: 0.5,
              max: 4.0,
              divisions: 3,
              label: '${_speedMultiplier}x',
              onChanged: (v) => setState(() => _speedMultiplier = v),
            ),
            const SizedBox(height: 16),
            const Text('Win Condition'),
            SegmentedButton<WinCondition>(
              segments: const [
                ButtonSegment(value: WinCondition.domination, label: Text('Domination')),
                ButtonSegment(value: WinCondition.timeAttack, label: Text('Time Attack')),
              ],
              selected: {_winCondition},
              onSelectionChanged: (s) => setState(() => _winCondition = s.first),
            ),
            const Spacer(),
            Center(
              child: NeonButton(
                label: 'START BATTLE',
                onPressed: _start,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/features/match_setup/presentation/match_setup_screen_test.dart`
Expected: PASS (1 test).

- [ ] **Step 7: Commit**

```bash
git add lib/features/match_setup/ test/features/match_setup/
git commit -m "Add match config domain and match setup screen"
```

---

## Task 13: Arena Painter — Canvas Rendering Layers

**Files:**
- Create: `lib/features/arena_simulation/presentation/arena_painter.dart`
- Test: `test/features/arena_simulation/presentation/arena_painter_test.dart`

**Interfaces:**
- Consumes: `SimulationState` (Task 8), `TerritoryEngine.sectorOwners` (Task 6), `Particle`/`FloatingText` (Task 7).
- Produces: `ArenaPainter({required SimulationState state, required double arenaRadius, required double rimAngle})` extends `CustomPainter`, painting (in order): background disc, rotating rim, 360 laser rays per sector owner, particles, floating text, ball tokens (glow + image/initials + border). `shouldRepaint` returns `true` always (state mutates in place every frame).

- [ ] **Step 1: Write a failing smoke test (canvas painting is not meaningfully unit-testable beyond "does it run without throwing")**

```dart
// test/features/arena_simulation/presentation/arena_painter_test.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_painter.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';

void main() {
  test('paint runs without throwing for a live simulation state', () async {
    final controller = MatchSimulationController(
      const [
        CustomBall(id: 'a', name: 'A', primaryColor: Colors.red, glowColor: Colors.pink),
        CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan),
      ],
      arenaRadius: 260.0,
      seed: 1,
    );
    controller.tick(1 / 60);

    final painter = ArenaPainter(
      state: controller.state,
      arenaRadius: 260.0,
      rimAngle: 0.5,
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter.paint(canvas, const Size(520, 520));
    final picture = recorder.endRecording();
    expect(picture, isNotNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/arena_simulation/presentation/arena_painter_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement `ArenaPainter`**

```dart
// lib/features/arena_simulation/presentation/arena_painter.dart
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/simulation_state.dart';

class ArenaPainter extends CustomPainter {
  final SimulationState state;
  final double arenaRadius;
  final double rimAngle;

  ArenaPainter({
    required this.state,
    required this.arenaRadius,
    required this.rimAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.shortestSide / (2 * arenaRadius);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale, scale);

    _paintBackground(canvas);
    _paintRim(canvas);
    _paintLaserRays(canvas);
    _paintParticles(canvas);
    _paintBallTokens(canvas);
    _paintFloatingText(canvas);

    canvas.restore();
  }

  void _paintBackground(Canvas canvas) {
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        arenaRadius,
        [AppColors.arenaDiscStart, AppColors.arenaDiscEnd],
      );
    canvas.drawCircle(Offset.zero, arenaRadius, paint);
  }

  void _paintRim(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = AppColors.rimGlow
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4.0);
    canvas.drawCircle(Offset.zero, arenaRadius, paint);
  }

  void _paintLaserRays(Canvas canvas) {
    final owners = state.territory.sectorOwners;
    for (var i = 0; i < owners.length; i++) {
      final ownerId = owners[i];
      if (ownerId.isEmpty) continue;
      final ownerBall = state.balls.where((b) => b.config.id == ownerId);
      if (ownerBall.isEmpty) continue;
      final ball = ownerBall.first;

      final theta = rimAngle + (i * (2 * math.pi / 360));
      final rimPoint = Offset(math.cos(theta), math.sin(theta)) * arenaRadius;

      final paint = Paint()
        ..color = ball.config.primaryColor.withOpacity(0.85)
        ..strokeWidth = 1.2;
      canvas.drawLine(ball.position, rimPoint, paint);
    }
  }

  void _paintParticles(Canvas canvas) {
    for (final particle in state.particles.particles) {
      final lifeRatio = 1.0 - (particle.age / particle.lifespan).clamp(0.0, 1.0);
      final paint = Paint()..color = particle.color.withOpacity(lifeRatio);
      canvas.drawCircle(particle.position, 3.0 * lifeRatio, paint);
    }
  }

  void _paintBallTokens(Canvas canvas) {
    for (final ball in state.balls) {
      final glowPaint = Paint()
        ..color = ball.config.glowColor.withOpacity(0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6.0);
      canvas.drawCircle(ball.position, ball.radius + 4, glowPaint);

      final fillPaint = Paint()..color = ball.config.primaryColor;
      canvas.drawCircle(ball.position, ball.radius, fillPaint);

      final image = ball.cachedUiImage;
      if (image != null) {
        canvas.save();
        canvas.clipPath(Path()..addOval(Rect.fromCircle(center: ball.position, radius: ball.radius)));
        final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
        final dstRect = Rect.fromCircle(center: ball.position, radius: ball.radius);
        canvas.drawImageRect(image, srcRect, dstRect, Paint());
        canvas.restore();
      } else {
        final textPainter = TextPainter(
          text: TextSpan(
            text: ball.config.name.isNotEmpty ? ball.config.name.substring(0, 1).toUpperCase() : '?',
            style: TextStyle(color: Colors.white, fontSize: ball.radius, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          ball.position - Offset(textPainter.width / 2, textPainter.height / 2),
        );
      }

      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = Colors.white;
      canvas.drawCircle(ball.position, ball.radius, borderPaint);
    }
  }

  void _paintFloatingText(Canvas canvas) {
    for (final text in state.floatingTexts.items) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: text.text,
          style: TextStyle(
            color: text.color.withOpacity(text.opacity),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, text.position);
    }
  }

  @override
  bool shouldRepaint(covariant ArenaPainter oldDelegate) => true;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/arena_simulation/presentation/arena_painter_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add lib/features/arena_simulation/presentation/arena_painter.dart test/features/arena_simulation/presentation/arena_painter_test.dart
git commit -m "Add arena painter with layered canvas rendering"
```

---

## Task 14: Arena Canvas & Battle Screen (Ticker-Driven, Responsive)

**Files:**
- Create: `lib/features/arena_simulation/presentation/arena_canvas.dart`
- Create: `lib/features/arena_simulation/presentation/scoreboard_overlay.dart`
- Create: `lib/features/arena_simulation/presentation/winner_modal.dart`
- Create: `lib/features/arena_simulation/presentation/arena_battle_screen.dart`
- Test: `test/features/arena_simulation/presentation/scoreboard_overlay_test.dart`
- Test: `test/features/arena_simulation/presentation/arena_battle_screen_test.dart`

**Interfaces:**
- Consumes: `MatchSimulationController`/`SimulationState`/`MatchStatus` (Task 8), `ArenaPainter` (Task 13), `MatchConfig` (Task 12), `NeonButton`/`CircularBallPreview` (Tasks 9-10).
- Produces:
  - `ArenaCanvas({required SimulationState state, required double arenaRadius, required double rimAngle})` — thin `CustomPaint` wrapper around `ArenaPainter`.
  - `ScoreboardOverlay({required List<SimulationBall> balls})` — percentage bars per contestant (`lineCount / 360`).
  - `WinnerModal({required CustomBall winner, required VoidCallback onReplay, required VoidCallback onExit})` — overlay with avatar, name, trophy icon, Replay/Exit actions.
  - `ArenaBattleScreen({required MatchConfig config})` — `StatefulWidget` that owns a `Ticker`, drives `MatchSimulationController.tick`, and lays out responsively per Global Constraints (portrait: score bar below arena; landscape/web: score bar beside arena). Shows `WinnerModal` when `state.status == MatchStatus.finished`.

- [ ] **Step 1: Write a failing widget test for the scoreboard**

```dart
// test/features/arena_simulation/presentation/scoreboard_overlay_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_ball.dart';
import 'package:ballwars/features/arena_simulation/presentation/scoreboard_overlay.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';

void main() {
  testWidgets('renders a percentage label per ball', (tester) async {
    final balls = [
      SimulationBall(
        config: const CustomBall(id: 'a', name: 'A', primaryColor: Colors.red, glowColor: Colors.pink),
        position: Offset.zero,
        velocity: Offset.zero,
        radius: 20,
        lineCount: 180,
      ),
      SimulationBall(
        config: const CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan),
        position: Offset.zero,
        velocity: Offset.zero,
        radius: 20,
        lineCount: 90,
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ScoreboardOverlay(balls: balls)),
    ));

    expect(find.text('A: 50%'), findsOneWidget);
    expect(find.text('B: 25%'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/arena_simulation/presentation/scoreboard_overlay_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement `ScoreboardOverlay`**

```dart
// lib/features/arena_simulation/presentation/scoreboard_overlay.dart
import 'package:flutter/material.dart';
import '../domain/simulation_ball.dart';

class ScoreboardOverlay extends StatelessWidget {
  final List<SimulationBall> balls;

  const ScoreboardOverlay({super.key, required this.balls});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: balls.map((ball) {
        final percent = ((ball.lineCount / 360) * 100).round();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${ball.config.name}: $percent%', style: TextStyle(color: ball.config.primaryColor)),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ball.lineCount / 360,
                  color: ball.config.primaryColor,
                  backgroundColor: Colors.white12,
                  minHeight: 8,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/arena_simulation/presentation/scoreboard_overlay_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Implement `ArenaCanvas`**

```dart
// lib/features/arena_simulation/presentation/arena_canvas.dart
import 'package:flutter/material.dart';
import '../domain/simulation_state.dart';
import 'arena_painter.dart';

class ArenaCanvas extends StatelessWidget {
  final SimulationState state;
  final double arenaRadius;
  final double rimAngle;

  const ArenaCanvas({
    super.key,
    required this.state,
    required this.arenaRadius,
    required this.rimAngle,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: ArenaPainter(state: state, arenaRadius: arenaRadius, rimAngle: rimAngle),
        size: Size.infinite,
      ),
    );
  }
}
```

- [ ] **Step 6: Implement `WinnerModal`**

```dart
// lib/features/arena_simulation/presentation/winner_modal.dart
import 'package:flutter/material.dart';
import '../../../core/widgets/neon_button.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../../ball_management/presentation/widgets/circular_ball_preview.dart';

class WinnerModal extends StatelessWidget {
  final CustomBall winner;
  final VoidCallback onReplay;
  final VoidCallback onExit;

  const WinnerModal({
    super.key,
    required this.winner,
    required this.onReplay,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.85),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, color: Colors.amber, size: 64),
          const SizedBox(height: 16),
          CircularBallPreview(ball: winner, size: 140),
          const SizedBox(height: 16),
          Text(
            winner.name,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              NeonButton(label: 'REPLAY', onPressed: onReplay, color: winner.primaryColor),
              const SizedBox(width: 16),
              NeonButton(label: 'EXIT', onPressed: onExit),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: Write a failing widget test for the battle screen**

```dart
// test/features/arena_simulation/presentation/arena_battle_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_battle_screen.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';

void main() {
  testWidgets('renders the arena and scoreboard for a fresh match', (tester) async {
    final config = MatchConfig(
      contestants: const [
        CustomBall(id: 'a', name: 'A', primaryColor: Colors.red, glowColor: Colors.pink),
        CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan),
      ],
    );

    await tester.pumpWidget(MaterialApp(
      home: ArenaBattleScreen(config: config),
    ));
    await tester.pump();

    expect(find.text('A: 50%'), findsOneWidget);
    expect(find.text('B: 50%'), findsOneWidget);

    // Stop the ticker cleanly before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
```

- [ ] **Step 8: Run test to verify it fails**

Run: `flutter test test/features/arena_simulation/presentation/arena_battle_screen_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 9: Implement `ArenaBattleScreen`**

```dart
// lib/features/arena_simulation/presentation/arena_battle_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../application/match_simulation_controller.dart';
import '../domain/simulation_state.dart';
import '../../match_setup/domain/match_config.dart';
import 'arena_canvas.dart';
import 'scoreboard_overlay.dart';
import 'winner_modal.dart';

class ArenaBattleScreen extends StatefulWidget {
  final MatchConfig config;
  final int? seed;

  const ArenaBattleScreen({super.key, required this.config, this.seed});

  @override
  State<ArenaBattleScreen> createState() => _ArenaBattleScreenState();
}

class _ArenaBattleScreenState extends State<ArenaBattleScreen>
    with SingleTickerProviderStateMixin {
  static const double _arenaRadius = 260.0;

  late MatchSimulationController _controller;
  late Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  double _rimAngle = 0.0;
  late SimulationState _state;

  @override
  void initState() {
    super.initState();
    _initMatch();
    _ticker = createTicker(_onTick)..start();
  }

  void _initMatch() {
    _controller = MatchSimulationController(
      widget.config.contestants,
      arenaRadius: _arenaRadius,
      seed: widget.seed,
    );
    _state = _controller.state;
    _rimAngle = 0.0;
    _lastElapsed = Duration.zero;
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (dt <= 0) return;

    _controller.tick(dt * widget.config.speedMultiplier);
    _rimAngle += dt * 0.5;

    setState(() {
      _state = _controller.state;
    });
  }

  void _replay() {
    setState(_initMatch);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFinished = _state.winnerId != null;
    final winnerBall = isFinished
        ? _state.balls.firstWhere((b) => b.config.id == _state.winnerId).config
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Ball Wars')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isPortrait = constraints.maxHeight >= constraints.maxWidth;
            final arena = ArenaCanvas(state: _state, arenaRadius: _arenaRadius, rimAngle: _rimAngle);
            final scoreboard = Padding(
              padding: const EdgeInsets.all(16),
              child: ScoreboardOverlay(balls: _state.balls),
            );

            final content = isPortrait
                ? Column(children: [Expanded(child: arena), scoreboard])
                : Row(children: [
                    Expanded(child: arena),
                    SizedBox(width: 240, child: scoreboard),
                  ]);

            return Stack(
              children: [
                content,
                if (isFinished && winnerBall != null)
                  Positioned.fill(
                    child: WinnerModal(
                      winner: winnerBall,
                      onReplay: _replay,
                      onExit: () => Navigator.of(context).maybePop(),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
```

- [ ] **Step 10: Run test to verify it passes**

Run: `flutter test test/features/arena_simulation/presentation/arena_battle_screen_test.dart`
Expected: PASS (1 test).

- [ ] **Step 11: Commit**

```bash
git add lib/features/arena_simulation/presentation/ test/features/arena_simulation/presentation/scoreboard_overlay_test.dart test/features/arena_simulation/presentation/arena_battle_screen_test.dart
git commit -m "Add arena canvas, scoreboard, winner modal, and responsive battle screen"
```

---

## Task 15: Canvas Image Helper — Decode & Cache Ball Images

**Files:**
- Create: `lib/core/utils/canvas_image_helper.dart`
- Modify: `lib/features/arena_simulation/application/match_simulation_controller.dart`
- Test: `test/core/utils/canvas_image_helper_test.dart`

**Interfaces:**
- Consumes: `Uint8List` image bytes (from `CustomBall.imageBytes`, Task 3), `SimulationBall.cachedUiImage` field (Task 5).
- Produces: `CanvasImageHelper.decode(Uint8List bytes) -> Future<ui.Image>` (decodes once; callers cache the result themselves — this keeps the helper stateless and easy to test). `MatchSimulationController` gains `Future<void> preloadImages()`, which decodes each contestant's `imageBytes` (if present) and assigns the result to the matching `SimulationBall.cachedUiImage`; balls with no `imageBytes` are left untouched (painter already falls back to initials).

- [ ] **Step 1: Write a failing test for the decode helper**

```dart
// test/core/utils/canvas_image_helper_test.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/utils/canvas_image_helper.dart';

Future<Uint8List> _tinyPngBytes() async {
  // 1x1 transparent PNG, valid and tiny — good for a fast decode test.
  const base64Png =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
  return base64Decode(base64Png);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('decode returns a ui.Image matching the source pixel dimensions', () async {
    final bytes = await _tinyPngBytes();
    final ui.Image image = await CanvasImageHelper.decode(bytes);
    expect(image.width, 1);
    expect(image.height, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/utils/canvas_image_helper_test.dart`
Expected: FAIL — `canvas_image_helper.dart` doesn't exist.

- [ ] **Step 3: Implement `CanvasImageHelper`**

```dart
// lib/core/utils/canvas_image_helper.dart
import 'dart:typed_data';
import 'dart:ui' as ui;

class CanvasImageHelper {
  CanvasImageHelper._();

  static Future<ui.Image> decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/utils/canvas_image_helper_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Add `preloadImages()` to `MatchSimulationController`**

Modify `lib/features/arena_simulation/application/match_simulation_controller.dart`: add the import and method below (the constructor and all other members stay as implemented in Task 8).

```dart
import '../../../core/utils/canvas_image_helper.dart';
```

```dart
  Future<void> preloadImages() async {
    for (final ball in _balls) {
      final bytes = ball.config.imageBytes;
      if (bytes == null) continue;
      ball.cachedUiImage = await CanvasImageHelper.decode(bytes);
    }
  }
```

- [ ] **Step 6: Call `preloadImages()` from the battle screen**

Modify `lib/features/arena_simulation/presentation/arena_battle_screen.dart`'s `_initMatch()` (Task 14) so it triggers preloading after constructing the controller:

```dart
  void _initMatch() {
    _controller = MatchSimulationController(
      widget.config.contestants,
      arenaRadius: _arenaRadius,
      seed: widget.seed,
    );
    _state = _controller.state;
    _rimAngle = 0.0;
    _lastElapsed = Duration.zero;
    _controller.preloadImages().then((_) {
      if (mounted) setState(() {});
    });
  }
```

- [ ] **Step 7: Run the full test suite**

Run: `flutter test`
Expected: PASS (all tests, every file).

- [ ] **Step 8: Commit**

```bash
git add lib/core/utils/canvas_image_helper.dart lib/features/arena_simulation/application/match_simulation_controller.dart lib/features/arena_simulation/presentation/arena_battle_screen.dart test/core/utils/canvas_image_helper_test.dart
git commit -m "Decode and cache uploaded ball images for canvas rendering"
```

---

## Task 16: Wire Up Navigation in `app.dart`

**Files:**
- Modify: `lib/app.dart`
- Test: `test/app_navigation_test.dart`

**Interfaces:**
- Consumes: `LocalBallRepository` (Task 4), `BallLibraryScreen` (Task 11), `MatchSetupScreen` (Task 12), `ArenaBattleScreen` (Task 14).
- Produces: `BallWarsApp` now provides real navigation: a home screen with "Ball Library" and "Match Setup" `NeonButton`s, routing into each screen, and `MatchSetupScreen.onStartBattle` pushing `ArenaBattleScreen`.

- [ ] **Step 1: Write a failing navigation test**

```dart
// test/app_navigation_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/app.dart';

void main() {
  testWidgets('home screen navigates to match setup and starts a battle', (tester) async {
    await tester.pumpWidget(const BallWarsApp());

    expect(find.text('MATCH SETUP'), findsOneWidget);
    await tester.tap(find.text('MATCH SETUP'));
    await tester.pumpAndSettle();

    expect(find.text('Select 2-4 Balls'), findsOneWidget);

    await tester.tap(find.text('United States'));
    await tester.tap(find.text('Russia'));
    await tester.pump();

    await tester.tap(find.text('START BATTLE'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.byType(Scaffold), findsWidgets);

    // Stop tickers cleanly before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/app_navigation_test.dart`
Expected: FAIL — home screen buttons don't exist yet.

- [ ] **Step 3: Rewrite `lib/app.dart` with real navigation**

```dart
// lib/app.dart
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/neon_button.dart';
import 'features/ball_management/data/local_ball_repository.dart';
import 'features/ball_management/presentation/ball_library_screen.dart';
import 'features/arena_simulation/presentation/arena_battle_screen.dart';
import 'features/match_setup/presentation/match_setup_screen.dart';

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

class _HomeScreen extends StatelessWidget {
  final LocalBallRepository repository;

  const _HomeScreen({required this.repository});

  @override
  Widget build(BuildContext context) {
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
```

- [ ] **Step 4: Update the Task 1 smoke test for the new home screen text**

Edit `test/widget_test_smoke.dart`, replacing the `expect` line:

```dart
    expect(find.text('Ball Wars'), findsOneWidget);
```

(No change needed — the home screen still shows the 'Ball Wars' title text, so this assertion continues to pass.)

- [ ] **Step 5: Run the navigation test to verify it passes**

Run: `flutter test test/app_navigation_test.dart`
Expected: PASS (1 test).

- [ ] **Step 6: Run the full test suite**

Run: `flutter test`
Expected: PASS (all tests, every file).

- [ ] **Step 7: Commit**

```bash
git add lib/app.dart test/app_navigation_test.dart
git commit -m "Wire up home screen navigation to ball library, match setup, and battle screen"
```

---

## Task 17: Manual Verification on Web & Mobile

**Files:** none (manual QA pass — no code changes expected unless a bug is found, in which case fix it in the relevant file from Tasks 1-15 and re-run its tests).

- [ ] **Step 1: Run on Flutter Web**

Run: `flutter run -d chrome`
Verify manually:
- Home screen shows Ball Library / Match Setup buttons.
- Ball Library shows 4 presets; Create New Ball opens the editor, image upload works, save adds a new ball to the grid.
- Match Setup: selecting 2-4 balls enables Start Battle; speed slider and win condition selector work.
- Battle screen: arena renders centered and square, rim rotates, laser rays draw from each ball to its owned sectors, balls bounce and collide, `+XX LINES` floating text and spark particles appear on collision, scoreboard percentages update live.
- Triggering a near-100% domination shows the Winner Modal with avatar, name, trophy, Replay/Exit; Replay restarts the match; Exit returns to Match Setup.

- [ ] **Step 2: Run on a mobile target**

Run: `flutter run -d <android-emulator-or-ios-simulator-id>` (use `flutter devices` to list available targets)
Verify manually:
- Portrait layout stacks the scoreboard below the arena; rotate to landscape and confirm it moves beside the arena.
- All buttons (Create New Ball, Start Battle, Replay/Exit) are easily tappable (no accidental mis-taps from undersized targets).
- Image upload from the mobile file picker works and displays correctly on the ball token.

- [ ] **Step 3: Fix any issues found, re-run the affected task's tests, and commit**

If manual verification surfaces a bug, fix it in the owning file, re-run that task's test file to confirm no regression, then commit with a message describing the fix (e.g. `git commit -m "Fix scoreboard overflow on narrow portrait screens"`).

- [ ] **Step 4: Final full-suite check**

Run: `flutter test`
Expected: PASS (all tests).

- [ ] **Step 5: Push the branch**

Only after the user confirms they want this pushed:

```bash
git push -u origin master
```
