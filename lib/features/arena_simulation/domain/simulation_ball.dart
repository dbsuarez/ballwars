import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../ball_management/domain/custom_ball.dart';
import 'fan_line.dart';
import 'power_up.dart';

class SimulationBall {
  final CustomBall config;
  Offset position;
  Offset velocity;
  double radius;
  int lineCount;
  ui.Image? cachedUiImage;
  bool isEliminated = false;
  double rotation = 0.0; // Visual spin from collisions
  double angularVelocity = 0.0; // Angular velocity from collisions
  final int? hairstyle;
  final Color? hairColor;

  // Lines from this ball to the rim slots it owns
  final List<FanLine> fanLines = [];

  // Power-up state (Arsenal and All-Out modes; unused in Threads)
  /// Life points in Arsenal mode (set to `PowerUpTuning.arenaLife` there).
  double life = 0;

  /// Primary and optional secondary equipped weapon.
  PowerUpKind? held;
  PowerUpKind? heldSecondary;
  String? heldSkillId;
  String? heldSecondarySkillId;
  bool heldTwoHanded = false;
  bool heldSecondaryTwoHanded = false;

  List<PowerUpKind> get equippedWeapons => [?held, ?heldSecondary];

  void equipWeapon(
    PowerUpKind weapon, {
    required bool dualWield,
    bool? twoHanded,
    String? skillId,
  }) {
    assert(weapon.isWeapon);
    final usesTwoHands = twoHanded ?? weapon.isTwoHanded;
    if (!dualWield) {
      held = weapon;
      heldSecondary = null;
      heldSkillId = skillId;
      heldSecondarySkillId = null;
      heldTwoHanded = usesTwoHands;
      heldSecondaryTwoHanded = false;
      return;
    }

    // A two-handed weapon clears both hands. Picking up any weapon while one
    // is held drops it and starts a fresh one-handed loadout.
    if (usesTwoHands) {
      held = weapon;
      heldSecondary = null;
      heldSkillId = skillId;
      heldSecondarySkillId = null;
      heldTwoHanded = true;
      heldSecondaryTwoHanded = false;
      return;
    }
    if (heldTwoHanded) {
      held = weapon;
      heldSecondary = null;
      heldSkillId = skillId;
      heldSecondarySkillId = null;
      heldTwoHanded = false;
      heldSecondaryTwoHanded = false;
      return;
    }

    if (held == null) {
      held = weapon;
      heldSkillId = skillId;
      heldTwoHanded = false;
    } else {
      heldSecondary = weapon;
      heldSecondarySkillId = skillId;
      heldSecondaryTwoHanded = false;
    }
  }

  void removeWeapon(PowerUpKind weapon) {
    if (held == weapon) {
      held = heldSecondary;
      heldSkillId = heldSecondarySkillId;
      heldTwoHanded = heldSecondaryTwoHanded;
      heldSecondary = null;
      heldSecondarySkillId = null;
      heldSecondaryTwoHanded = false;
    } else if (heldSecondary == weapon) {
      heldSecondary = null;
      heldSecondarySkillId = null;
      heldSecondaryTwoHanded = false;
    }
  }

  int speedLeft = 0;
  double speedFactor = PowerUpTuning.speedFactor;
  int frozenLeft = 0;
  double? frozenDamageMultiplierOverride;
  double? frozenCollisionDamageOverride;
  int stunnedLeft = 0;
  int ghostLeft = 0;
  int flailLeft = 0;
  int repulsorLeft = 0;
  int timeBubbleLeft = 0;
  int vampireLeft = 0;
  int mirrorCharges = 0;
  int overchargeLeft = 0;
  int gremlinShots = 0;
  int magneticFieldLeft = 0;
  final Set<SimulationBall> magneticReflectedOwners = {};
  int goldenArmorHits = 0;
  int stickyGooLeft = 0;
  int burningLeft = 0;
  int poisonLeft = 0;

  /// All-Out sword sweep: steps left of the wider cutting reach after picking up a knife.
  int sweepLeft = 0;

  /// Threads held at the start of the match (All-Out hearts show the share left).
  int startLines = 0;

  /// Steps left of the wince on a "Faces" ball after a hit or a lost thread (cosmetic only).
  int hurtFlashLeft = 0;
  bool magnetPending = false;

  /// Direction a held shield faces, in radians: it turns toward the biggest threat (see
  /// `PowerUpSystem`). Blocking works from every side; this only shows where it braces.
  double shieldAngle = 0;
  final Set<PowerUpKind> trackingItems = {};
  final Map<PowerUpKind, String> activeEffectSkillIds = {};

  /// Steps left of aiming before a gun fires at [aimTarget].
  int aimLeft = 0;
  SimulationBall? aimTarget;

  /// Gatling rounds still to fire.
  int burstLeft = 0;

  bool get isGhost => ghostLeft > 0;

  SimulationBall({
    required this.config,
    required this.position,
    required this.velocity,
    required this.radius,
    required this.lineCount,
    this.cachedUiImage,
    this.hairstyle,
    this.hairColor,
  });
}
