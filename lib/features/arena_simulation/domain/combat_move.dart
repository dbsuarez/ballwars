import '../../skills/domain/skill_library.dart';

/// Presentation attribution captured when damage is accepted. Never selects a
/// skill by display name; duplicate names are valid independent skills.
class CombatMove {
  const CombatMove({required this.label, required this.sourceId, this.skill});
  final String label;
  final String sourceId;
  final SkillDefinition? skill;

  static const collision = CombatMove(
    label: 'Collision',
    sourceId: 'event.collision',
  );
  static const threadCut = CombatMove(
    label: 'Thread cut',
    sourceId: 'event.thread-cut',
  );
  static const score = CombatMove(
    label: 'Knockout lead',
    sourceId: 'event.score',
  );

  factory CombatMove.hit(
    String label, {
    SkillDefinition? skill,
    String? sourceId,
  }) => CombatMove(
    label: label,
    sourceId:
        skill?.id ??
        sourceId ??
        (label == 'Collision'
            ? collision.sourceId
            : label == 'Frozen collision'
            ? 'event.frozen-collision'
            : 'event.unknown'),
    skill: skill,
  );
}
