# CLAUDE_CODE_TASK: Ball Wars Simulator - Full Implementation Specification

## 1. Project Context & Objectives
You are tasked with building a Flutter web-first simulation game titled **"Ball Wars"** (also known as Circle Battle / Territory Ball Simulator).

In this application:
1. Users create and customize contestant "Balls" (custom name, uploaded image/flag/avatar, primary territory color, glow color, and base attributes).
2. Users select 2 to 4 contestant balls and configure an arena match.
3. The match runs inside a glowing circular arena with continuous rim rotation.
4. Balls bounce freely inside the arena boundary with 2D elastic physics and collide with each other.
5. Each ball projects dynamic laser rays from its moving center position to the 360 discrete sectors on the arena rim that it currently owns.
6. When balls collide, line-stealing logic triggers: the dominant collider steals lines from the opponent, spawns spark particles, and shows a floating indicator (e.g. `+35 LINES`).
7. When any ball falls below 10% remaining lines, the simulation activates a dramatic **Slow Motion** mode.
8. When one contestant claims 100% (or $\ge 98\%$) of the arena, the match halts and presents an animated victory overlay showing the winner's circular avatar, name, trophy, and replay controls.

---

## 2. Technical Stack & Architecture Constraints
- **Framework:** Flutter (Web primary, responsive for desktop browsers, tablets, and mobile portrait).
- **Rendering Engine:** Flutter Canvas API (`CustomPaint`, `CustomPainter`, `AnimationController` / `Ticker`).
- **Do NOT use Flame engine** for this build; keep the physics and ray rendering pure Dart + Canvas for maximum control and lightweight performance.
- **Image Handling:** Support web image uploads via file picking using raw bytes (`Uint8List`) so images can be displayed immediately on canvas (`dart:ui.Image` or circular image widgets) without relying on local filesystem paths (`dart:io` `File` is NOT supported on web).
- **State Management:** Riverpod or `ChangeNotifier` / `ValueNotifier` clean separation.
- **Architecture Style:** Clean, feature-first structure separating Domain logic (Physics, Territory, Simulation), Presentation (Canvas, Painter, UI), and Data/Storage.

---

## 3. Directory Structure to Generate
```text
lib/
├── main.dart
├── app.dart
├── core/
│   ├── theme/
│   │   ├── app_colors.dart
│   │   └── app_theme.dart
│   ├── utils/
│   │   ├── canvas_image_helper.dart
│   │   ├── sound_effects.dart
│   │   └── math_utils.dart
│   └── widgets/
│       ├── neon_button.dart
│       └── glowing_card.dart
├── features/
│   ├── ball_management/
│   │   ├── domain/
│   │   │   ├── custom_ball.dart
│   │   │   └── ball_repository.dart
│   │   ├── data/
│   │   │   └── local_ball_repository.dart
│   │   └── presentation/
│   │       ├── ball_editor_dialog.dart
│   │       ├── ball_library_screen.dart
│   │       └── widgets/
│   │           └── circular_ball_preview.dart
│   ├── match_setup/
│   │   ├── domain/
│   │   │   └── match_config.dart
│   │   └── presentation/
│   │       ├── match_setup_screen.dart
│   │       └── widgets/
│   │           └── ball_selection_carousel.dart
│   └── arena_simulation/
│       ├── domain/
│       │   ├── arena_physics_engine.dart
│       │   ├── territory_engine.dart
│       │   ├── simulation_ball.dart
│       │   ├── particle_system.dart
│       │   ├── floating_text.dart
│       │   └── simulation_state.dart
│       ├── application/
│       │   └── match_simulation_controller.dart
│       └── presentation/
│           ├── arena_battle_screen.dart
│           ├── arena_canvas.dart
│           ├── arena_painter.dart
│           ├── scoreboard_overlay.dart
│           └── winner_modal.dart
```

---

## 4. Detailed Implementation Requirements

### 4.1 Domain Models & Data Structures

#### `CustomBall`
```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';

class CustomBall {
  final String id;
  final String name;
  final Uint8List? imageBytes; // Web-compatible raw image bytes
  final String? assetPath;     // Fallback for default presets
  final Color primaryColor;
  final Color glowColor;
  final double baseSpeed;      // Default ~320.0 px/s
  final double mass;           // Default 1.0

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

#### `SimulationBall`
```dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'custom_ball.dart';

class SimulationBall {
  final CustomBall config;
  Offset position;            // Current 2D position in arena coordinate space
  Offset velocity;            // Current 2D velocity vector
  double radius;              // Radius in arena units
  int lineCount;              // Current number of owned sectors (0..360)
  ui.Image? cachedUiImage;    // Decoded image cached for canvas drawing

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

---

### 4.2 Physics & Collision Engine (`arena_physics_engine.dart`)
Coordinate Space:
- The arena is a circle centered at `Offset(0, 0)` with radius `R` (e.g., $R = 260.0$ or scaled to canvas size).
- Ball radius $r = 0.08 \times R$.

#### 1. Circular Wall Bounce Calculation
For each active ball with position $\vec{P}$ and velocity $\vec{V}$:
- Distance from center: $d = \|\vec{P}\| = \sqrt{x^2 + y^2}$.
- If $d \ge (R - r)$:
  - Normal unit vector: $\hat{N} = \frac{\vec{P}}{d}$.
  - Velocity reflection: $\vec{V}' = \vec{V} - 2(\vec{V} \cdot \hat{N})\hat{N}$.
  - Clamp position to boundary: $\vec{P}' = \hat{N} \times (R - r)$.
  - Apply slight random angle jitter ($\pm 2^\circ$) to prevent repetitive loops.

#### 2. Ball-to-Ball Elastic Collisions
For any pair of balls $A$ and $B$:
- Distance vector: $\Delta\vec{P} = \vec{P}_B - \vec{P}_A$.
- Distance: $dist = \|\Delta\vec{P}\|$.
- Overlap distance: $minDist = r_A + r_B$.
- If $dist < minDist$:
  1. **Position correction (prevent sticking):**
     $$\text{overlap} = 0.5 \times (minDist - dist)$$
     $$\hat{N}_{col} = \frac{\Delta\vec{P}}{dist}$$
     $$\vec{P}_A \mathrel{-}= \hat{N}_{col} \times \text{overlap}$$
     $$\vec{P}_B \mathrel{+}= \hat{N}_{col} \times \text{overlap}$$
  2. **Elastic impulse resolution:**
     $$\vec{k} = \vec{V}_A - \vec{V}_B$$
     $$p = \frac{2 (\vec{k} \cdot \hat{N}_{col})}{m_A + m_B}$$
     $$\vec{V}_A \mathrel{-}= \hat{N}_{col} \times (p \times m_B)$$
     $$\vec{V}_B \mathrel{+}= \hat{N}_{col} \times (p \times m_A)$$
  3. **Trigger Collision Event:** Return collision point $\vec{P}_{contact} = \vec{P}_A + \hat{N}_{col} \times r_A$ and relative impact speed to the territory engine.

---

### 4.3 360-Sector Territory Engine (`territory_engine.dart`)
- Represent the arena perimeter as an array of 360 integer owner indices: `List<String> sectorOwners = List.filled(360, '');`
- Initial split for 2 balls: Ball 0 owns sectors $0 \dots 179$, Ball 1 owns sectors $180 \dots 359$.
- For $N$ balls: split $360 / N$ contiguous sectors per ball.

#### Collision Line-Steal Mechanics:
When Ball $A$ and Ball $B$ collide:
1. Determine winner of the hit: The ball with higher relative impact momentum or a slight random weight wins the clash.
2. Calculate stolen line count:
   $$\text{stealAmount} = \text{clamp}(20 + \text{random}(0 \dots 25), 10, 75)$$
3. Reassign up to `stealAmount` contiguous boundary sectors from the losing ball to the winning ball.
4. Spawn floating notification text near the winner: `+${stealAmount} LINES` in winner's primary color.
5. Spawn 20–30 spark particles at $\vec{P}_{contact}$ spraying in direction of the collision normal.

#### Slow Motion & Win Detection:
- If any ball's ownership drops $\le 15$ sectors ($\approx 4\%$), reduce simulation time scale to $0.25\times$ (Slow Motion trigger).
- If one ball reaches $360$ sectors (or all opponents reach $0$), set `matchStatus = MatchStatus.finished` and trigger winner modal.

---

### 4.4 Canvas Rendering Architecture (`arena_painter.dart`)
Implement custom painting in the following exact layer order:

1. **Background & Dark Stage:**
   - Draw dark circular arena disc with subtle radial gradient (`#0A0E17` to `#020408`).
2. **Rotating Outer Rim:**
   - Draw glowing white circular ring of radius $R$ with `StrokeWidth = 4.0` and `MaskFilter.blur(BlurStyle.solid, 4.0)`.
   - Rotate rim reference angle continuously: `rimAngle += dt * 0.5 rad/s`.
3. **Dynamic Laser Ray Projections:**
   - For every sector index $i \in [0 \dots 359]$:
     - Get owner ball $B$ for sector $i$.
     - Calculate sector perimeter position on rim:
       $$\theta_i = \text{rimAngle} + \left(i \times \frac{2\pi}{360}\right)$$
       $$\vec{T}_i = \left(\text{center.dx} + R \cos\theta_i, \text{center.dy} + R \sin\theta_i\right)$$
     - Draw thin line (`strokeWidth: 1.2`, `Color: B.primaryColor.withOpacity(0.85)`) from $B.position$ to $\vec{T}_i$.
4. **Spark Particles:**
   - Draw glowing circle particles with decaying alpha and radius.
5. **Floating Text Overlays:**
   - Render `+XX LINES` text moving upward with fading opacity using `TextPainter`.
6. **Contestant Ball Tokens:**
   - At each ball's `position`:
     - Draw outer neon glow circle (`BlurStyle.outer`, `radius: r + 4`).
     - Clip canvas to circle with radius $r$.
     - If `cachedUiImage` is present: `canvas.drawImageRect(...)` with `BoxFit.cover`.
     - Else: Draw solid fill with ball initials rendered via `TextPainter`.
     - Draw crisp border ring around the ball.

---

### 4.5 UI & Feature Screens

#### 1. Ball Library & Creator Screen
- Grid of existing balls. Include default presets (e.g. USA, Russia, Brazil, Japan, Neon Dragon, Cyber Orb).
- **"Create New Ball" Dialog:**
  - Name text field.
  - Web image uploader (using `file_picker` to read `Uint8List` image bytes).
  - Primary color picker & glow color picker with neon presets.
  - Interactive live circular ball preview with neon glow.
  - Save to local ball repository.

#### 2. Match Setup Screen
- Choose between 2, 3, or 4 contestant balls.
- Speed slider (0.5x, 1x, 2x, 4x).
- Win condition selector (100% domination or Time Attack).
- Big glowing "START BATTLE" button.

#### 3. Battle Screen
- Top Bar: Match title, Round counter, Live Slow-Motion badge indicator.
- Center: Centered responsive square arena maintaining 1:1 aspect ratio.
- Bottom: Real-time territory score bar showing percentage bars for each contestant.
- Control buttons: Pause/Play, Restart, Speed Toggle, Exit.
- **Victory Modal:** Overlay with winner's large glowing circular avatar, country/ball name, gold trophy icon, "NEXT BATTLE" and "REPLAY" actions.

---

## 5. Starter Preset Data
Provide these 4 built-in preset balls ready to play out-of-the-box:
1. **United States:** Color `#28E21B` (Neon Green), Glow `#70FF66`, Flag/Logo avatar.
2. **Russia:** Color `#00E5FF` (Neon Cyan), Glow `#80F3FF`, Flag/Logo avatar.
3. **Japan:** Color `#FF1744` (Neon Red/Pink), Glow `#FF617B`, Flag/Logo avatar.
4. **Brazil:** Color `#FFEA00` (Neon Yellow), Glow `#FFF370`, Flag/Logo avatar.

---

## 6. Implementation Checklist for Claude Code
- [ ] Initialize clean Flutter project structure with features, domain, application, and presentation layers.
- [ ] Implement `CustomBall` domain model with `Uint8List` byte storage for Web image compatibility.
- [ ] Implement image decoding helper to convert raw bytes to `dart:ui.Image` with in-memory caching.
- [ ] Build `ArenaPhysicsEngine` with circle-boundary reflection and 2-ball elastic collision resolution.
- [ ] Build `TerritoryEngine` with 360-sector array, line stealing, and win detection.
- [ ] Build `ArenaPainter` rendering rotating rim, 360 dynamic laser fan rays, glowing balls, particles, and floating indicators.
- [ ] Build Ball Creator Dialog with web file picker and live glowing circular preview.
- [ ] Build Match Setup screen and Winner celebration modal.
- [ ] Test on Flutter Web (`flutter run -d chrome`) to ensure 60 FPS smooth rendering.
