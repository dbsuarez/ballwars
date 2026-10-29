part of 'power_up_system.dart';

/// A cosmetic activation handle. Its source, not the selected artwork, owns its
/// lifetime. Retaining an expired visual handle prevents restarting short art.
class PersistentSkillEffect {
  PersistentSkillEffect({
    required this.key,
    required this.skill,
    required this.role,
    required this.center,
    required this.radius,
    required this.active,
    this.owner,
    this.target,
    this.samples,
    this.direction = const Offset(1, 0),
    this.steps = 180,
    this.activation = false,
  });
  final Object key;
  final bool activation;
  final SkillDefinition skill;
  final SkillVisualRole role;
  final SimulationBall? owner, target;
  final Offset Function() center;
  final double Function() radius;
  final bool Function() active;
  final List<Offset> Function()? samples;
  final Offset direction;
  final int steps;
  bool get isWorld =>
      role == SkillVisualRole.ground || role == SkillVisualRole.boundary;
  int age = 0;
}

class SkillVisualEvent {
  SkillVisualEvent(
    this.skill,
    this.role,
    this.position,
    this.step, {
    this.owner,
    this.target,
    this.direction = const Offset(1, 0),
    this.steps = 18,
  });
  final SkillDefinition skill;
  final SkillVisualRole role;
  final Offset position, direction;
  final SimulationBall? owner, target;
  final int step, steps;
  int age = 0;
}

/// Bounded cosmetic observations. No random draws, damage or physics mutations.
class PersistentSkillEffects {
  PersistentSkillEffects(this.system);
  final PowerUpSystem system;
  final Map<Object, PersistentSkillEffect> _handles = {};
  final List<SkillVisualEvent> events = [];
  final List<PersistentSkillEffect> _areas = [];
  void area(
    SimulationBall owner,
    SkillDefinition skill,
    Offset center,
    double radius,
  ) {
    if (_areas.length >= 128) return;
    final duration =
        system.match.skillLibrary
            .resolveVisual(skill, SkillVisualRole.ground)
            ?.durationSeconds ??
        .35;
    final steps = (duration * 60).round().clamp(1, 600);
    late final PersistentSkillEffect effect;
    effect = PersistentSkillEffect(
      key: Object(),
      skill: skill,
      role: SkillVisualRole.ground,
      activation: true,
      center: () => center,
      radius: () => radius,
      steps: steps,
      active: () => effect.age < steps,
    );
    _areas.add(effect);
  }

  final List<String> history = [];
  Iterable<PersistentSkillEffect> get handles => _handles.values;
  final Map<(SimulationBall, String, SkillVisualRole), PersistentSkillEffect>
  _watched = {};
  final Map<SimulationBall, List<(PowerUpKind, String)>> _equipment = {};
  final Map<Object, int> _statusValues = {};
  final Set<Object> _seen = {};
  final Set<(SimulationBall, String)> _broken = {};

  bool _alive(SimulationBall? b) => b == null || system._alive(b);
  int _remaining(SimulationBall b, PowerUpKind kind) => switch (kind) {
    PowerUpKind.speed => b.speedLeft,
    PowerUpKind.ghost => b.ghostLeft,
    PowerUpKind.repulsor => b.repulsorLeft,
    PowerUpKind.timeBubble => b.timeBubbleLeft,
    PowerUpKind.vampire => b.vampireLeft,
    PowerUpKind.mirror => b.mirrorCharges,
    PowerUpKind.overcharge => b.overchargeLeft,
    PowerUpKind.magneticField => b.magneticFieldLeft,
    PowerUpKind.goldenArmor => b.goldenArmorHits,
    PowerUpKind.freeze => b.frozenLeft,
    PowerUpKind.stickyGoo => b.stickyGooLeft,
    PowerUpKind.molotov => b.burningLeft,
    PowerUpKind.poisonSwamp => b.poisonLeft,
    PowerUpKind.gremlin => b.gremlinShots,
    PowerUpKind.shield ||
    PowerUpKind.orbitingFlail => b.equippedWeapons.contains(kind) ? 1 : 0,
    _ => 0,
  };

  void _log(SkillDefinition skill, SkillVisualRole role, String action) {
    history.add(
      '${system.match.stepCount}: ${skill.name} · ${role.name} · $action',
    );
    if (history.length > 60) history.removeAt(0);
  }

  void emit(
    SkillDefinition skill,
    SkillVisualRole role,
    Offset at, {
    SimulationBall? owner,
    SimulationBall? target,
    Offset direction = const Offset(1, 0),
  }) {
    _log(skill, role, 'event');
    if (!skill.visualBindings.containsKey(role)) return;
    final visual = system.match.skillLibrary.resolveVisual(skill, role);
    if (visual == null) return;
    events.add(
      SkillVisualEvent(
        skill,
        role,
        at,
        system.match.stepCount,
        owner: owner,
        target: target,
        direction: direction,
        steps: ((visual.durationSeconds ?? .3) * 60).round().clamp(1, 600),
      ),
    );
    if (events.length > 256) events.removeAt(0);
  }

  void defense(SimulationBall ball, PowerUpKind kind, {bool broken = false}) {
    final skill = system.visualSkill(kind, ball: ball);
    emit(skill, SkillVisualRole.block, ball.position, target: ball);
    if (broken) {
      _broken.add((ball, skill.id));
      emit(skill, SkillVisualRole.breakage, ball.position, target: ball);
    }
  }

  void watch(
    SimulationBall ball,
    SkillDefinition skill,
    SkillVisualRole role,
    bool Function() active,
  ) {
    final key = (ball, skill.id, role);
    // Refresh replaces the activation, so old expiry/age cannot leak into it.
    _watched[key] = PersistentSkillEffect(
      key: key,
      skill: skill,
      role: role,
      owner: role == SkillVisualRole.ownerStatus ? ball : null,
      target: role == SkillVisualRole.targetStatus ? ball : null,
      center: () => ball.position,
      radius: () => ball.radius * 1.5,
      active: active,
      steps: ((skill.durationSeconds ?? 3) * 60).round(),
    );
    _handles.remove(key);
  }

  void reset(SimulationBall ball) {
    _handles.removeWhere(
      (_, e) =>
          !e.isWorld && (identical(e.owner, ball) || identical(e.target, ball)),
    );
    _watched.removeWhere(
      (_, e) => identical(e.owner, ball) || identical(e.target, ball),
    );
    events.removeWhere(
      (e) => identical(e.owner, ball) || identical(e.target, ball),
    );
    _equipment.remove(ball);
    _statusValues.removeWhere(
      (key, _) =>
          key is (SimulationBall, PowerUpKind, String, SkillVisualRole) &&
          identical(key.$1, ball),
    );
  }

  List<(PowerUpKind, String)> _held(SimulationBall b) => [
    if (b.held != null) (b.held!, b.heldSkillId ?? 'builtin.${b.held!.name}'),
    if (b.heldSecondary != null)
      (
        b.heldSecondary!,
        b.heldSecondarySkillId ?? 'builtin.${b.heldSecondary!.name}',
      ),
  ];

  /// Snapshot equipment before mutation too, including items acquired/fired
  /// within the same simulation step.
  void rememberEquipment(SimulationBall ball) => _equipment[ball] = _held(ball);

  void sync() {
    for (final e in _areas) {
      e.age++;
    }
    _areas.removeWhere((e) => !e.active());
    for (final event in events) {
      event.age++;
    }
    events.removeWhere(
      (e) => e.age >= e.steps || !_alive(e.owner) || !_alive(e.target),
    );
    final seen = <Object>{};
    void observe(Object key, SkillDefinition skill, SkillVisualRole role) {
      seen.add(key);
      if (!_seen.contains(key)) _log(skill, role, 'started');
    }

    for (final e in system.castingArtwork) {
      observe(e, e.skill, SkillVisualRole.casting);
    }
    for (final e in system.muzzleArtwork) {
      observe(e, e.skill, SkillVisualRole.muzzle);
    }
    for (final e in system.weaponImpacts) {
      if (e.kind != null) {
        observe(
          e,
          system.visualSkill(e.kind!, skillId: e.skillId),
          SkillVisualRole.impact,
        );
      }
    }
    for (final e in system.explosions) {
      if (e.kind != null) {
        observe(
          e,
          system.visualSkill(e.kind!, skillId: e.skillId),
          SkillVisualRole.explosion,
        );
      }
    }
    for (final e in system.projectiles) {
      observe(
        e,
        system.projectileSkill(e) ?? system.visualSkill(e.kind, ball: e.owner),
        SkillVisualRole.trail,
      );
    }
    _seen
      ..clear()
      ..addAll(seen);
    final candidates = <Object, PersistentSkillEffect>{};
    void add(PersistentSkillEffect e) {
      if (e.active() && (e.isWorld || (_alive(e.owner) && _alive(e.target)))) {
        candidates[e.key] = e;
      }
    }

    void zone(
      Object key,
      PowerUpKind kind,
      Offset Function() center,
      double Function() radius,
      bool Function() active, {
      SimulationBall? owner,
      List<Offset> Function()? samples,
      Offset direction = const Offset(1, 0),
    }) => add(
      PersistentSkillEffect(
        key: key,
        skill: system.visualSkill(kind, ball: owner),
        role: samples == null
            ? SkillVisualRole.ground
            : SkillVisualRole.boundary,
        center: center,
        radius: radius,
        active: active,
        owner: owner,
        samples: samples,
        direction: direction,
      ),
    );
    final p = system;
    for (final e in _areas) {
      add(e);
    }
    for (final z in p.burningZones) {
      zone(
        z,
        PowerUpKind.molotov,
        () => z.position,
        () => z.radius,
        () => p.burningZones.contains(z),
        owner: z.owner,
      );
    }
    for (final z in p.fireWalls) {
      zone(
        z,
        PowerUpKind.fireWall,
        () => z.center,
        () => p.fieldRadius * .75,
        () => p.fireWalls.contains(z),
        owner: z.owner,
        direction: Offset.fromDirection(z.angle),
        // Wall samples are a straight zone, not curved-boundary artwork.
      );
    }
    for (final z in p.spikeWalls) {
      zone(
        z,
        PowerUpKind.spikeWall,
        () => z.position,
        () => p.fieldRadius,
        () => p.spikeWalls.contains(z),
        samples: () => z.spikePositions(p.fieldRadius * .96),
      );
    }
    for (final z in p.stickyGoo) {
      zone(
        z,
        PowerUpKind.stickyGoo,
        () => z.position,
        () => p.fieldRadius,
        () => p.stickyGoo.contains(z),
        samples: () => z.blobPositions(p.fieldRadius * .36),
      );
    }
    for (final z in p.poisonSwamps) {
      zone(
        z,
        PowerUpKind.poisonSwamp,
        () => z.position,
        () => p.fieldRadius,
        () => p.poisonSwamps.contains(z),
        samples: () => z.samplePositions(p.fieldRadius * .36),
      );
    }
    for (final z in p.portals) {
      zone(
        z,
        PowerUpKind.portal,
        () => z.position,
        () => p.fieldRadius * 1.4,
        () => p.portals.contains(z),
        samples: () => [z.position],
      );
    }
    for (final b in p.match.state.balls) {
      if (!_alive(b)) {
        reset(b);
        continue;
      }
      final now = _held(b);
      for (final old in _equipment[b] ?? <(PowerUpKind, String)>[]) {
        if (!now.contains(old)) {
          emit(
            p.visualSkill(old.$1, skillId: old.$2),
            SkillVisualRole.discard,
            b.position,
            owner: b,
          );
        }
      }
      _equipment[b] = now;
      void status(PowerUpKind kind, int remaining, SkillVisualRole role) {
        if (remaining <= 0) return;
        final skill = p.visualSkill(kind, ball: b);
        final key = (b, kind, skill.id, role);
        if (remaining > (_statusValues[key] ?? remaining)) _handles.remove(key);
        _statusValues[key] = remaining;
        add(
          PersistentSkillEffect(
            key: key,
            skill: skill,
            role: role,
            owner: role == SkillVisualRole.ownerStatus ? b : null,
            target: role == SkillVisualRole.targetStatus ? b : null,
            center: () => b.position,
            radius: () => b.radius * 1.5,
            active: () =>
                _alive(b) &&
                _remaining(b, kind) > 0 &&
                p.visualSkill(kind, ball: b).id == skill.id,
            steps:
                {
                  PowerUpKind.mirror,
                  PowerUpKind.goldenArmor,
                  PowerUpKind.shield,
                  PowerUpKind.orbitingFlail,
                  PowerUpKind.gremlin,
                }.contains(kind)
                ? 180
                : remaining,
          ),
        );
      }

      for (final entry in <PowerUpKind, int>{
        PowerUpKind.speed: b.speedLeft,
        PowerUpKind.ghost: b.ghostLeft,
        PowerUpKind.repulsor: b.repulsorLeft,
        PowerUpKind.timeBubble: b.timeBubbleLeft,
        PowerUpKind.vampire: b.vampireLeft,
        PowerUpKind.mirror: b.mirrorCharges,
        PowerUpKind.overcharge: b.overchargeLeft,
        PowerUpKind.magneticField: b.magneticFieldLeft,
        PowerUpKind.goldenArmor: b.goldenArmorHits,
        PowerUpKind.shield: b.equippedWeapons.contains(PowerUpKind.shield)
            ? 1
            : 0,
        PowerUpKind.orbitingFlail:
            b.equippedWeapons.contains(PowerUpKind.orbitingFlail) ? 1 : 0,
      }.entries) {
        status(entry.key, entry.value, SkillVisualRole.ownerStatus);
      }
      for (final entry in <PowerUpKind, int>{
        PowerUpKind.freeze: b.frozenLeft,
        PowerUpKind.stickyGoo: b.stickyGooLeft,
        PowerUpKind.molotov: b.burningLeft,
        PowerUpKind.poisonSwamp: b.poisonLeft,
        PowerUpKind.gremlin: b.gremlinShots,
      }.entries) {
        status(entry.key, entry.value, SkillVisualRole.targetStatus);
      }
    }
    void channel<T>(
      List<T> moves,
      SimulationBall Function(T) owner,
      PowerUpKind kind,
    ) {
      for (final move in moves) {
        final b = owner(move);
        add(
          PersistentSkillEffect(
            key: (
              kind == PowerUpKind.omegaTendrils ? b : move,
              kind,
              SkillVisualRole.ownerStatus,
            ),
            skill: p.visualSkill(kind, ball: b),
            role: SkillVisualRole.ownerStatus,
            owner: b,
            center: () => b.position,
            radius: () => b.radius * 1.5,
            active: () => kind == PowerUpKind.omegaTendrils
                ? moves.any((m) => identical(owner(m), b))
                : moves.contains(move),
          ),
        );
      }
    }

    channel(p.energyWaveAttacks, (a) => a.owner, PowerUpKind.energyWave);
    channel(p.omnislashAttacks, (a) => a.owner, PowerUpKind.busterSword);
    channel(p.ragingDemonAttacks, (a) => a.owner, PowerUpKind.ragingDemon);
    channel(p.shadowCloneAttacks, (a) => a.owner, PowerUpKind.shadowClone);
    channel(p.omegaTendrils, (a) => a.owner, PowerUpKind.omegaTendrils);
    channel(p.flameCones, (a) => a.owner, PowerUpKind.flamethrower);
    for (final z in p.tornadoes) {
      if (z.isAiming) continue;
      add(
        PersistentSkillEffect(
          key: z,
          skill: p.visualSkill(PowerUpKind.tornado, ball: z.owner),
          role: SkillVisualRole.targetStatus,
          owner: z.owner,
          target: z.target,
          center: () => z.target.position,
          radius: () => z.target.radius * 1.5,
          active: () => p.tornadoes.contains(z),
        ),
      );
    }
    _watched.removeWhere(
      (_, e) => !e.active() || !_alive(e.owner) || !_alive(e.target),
    );
    for (final e in _watched.values) {
      add(e);
    }
    for (final entry in _handles.entries.toList()) {
      if (!candidates.containsKey(entry.key)) {
        final e = entry.value;
        if ((e.isWorld || (_alive(e.owner) && _alive(e.target))) &&
            !_broken.contains((e.owner ?? e.target, e.skill.id))) {
          emit(
            e.skill,
            SkillVisualRole.expiry,
            e.center(),
            owner: e.isWorld ? null : e.owner,
            target: e.isWorld ? null : e.target,
          );
        }
        _log(e.skill, e.role, 'ended');
        _handles.remove(entry.key);
      }
    }
    _broken.clear();
    _statusValues.removeWhere((key, _) => !candidates.containsKey(key));
    for (final entry in candidates.entries) {
      final existing = _handles[entry.key];
      if (existing == null) {
        if (_handles.length >= 256) continue;
        _handles[entry.key] = entry.value;
        _log(entry.value.skill, entry.value.role, 'started');
      } else if (!existing.activation) {
        existing.age++;
      }
    }
  }
}
