import 'dart:convert';

import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:flutter_test/flutter_test.dart';

/// Postgres jsonb returns object keys sorted by length, then bytewise.
Object? jsonbOrder(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => '$key').toList()
      ..sort((a, b) => a.length != b.length
          ? a.length.compareTo(b.length)
          : a.compareTo(b));
    return {for (final key in keys) key: jsonbOrder(value[key])};
  }
  if (value is List) return [for (final item in value) jsonbOrder(item)];
  return value;
}

SkillLibrary edit(SkillLibrary library, PowerUpKind kind) =>
    library.withDefinition(
      library
          .builtIn(kind, PowerUpConfig.defaults)
          .copyWith(arsenalDamage: 31),
      PowerUpConfig.defaults,
    );

void main() {
  test('a library matches its stored copy whatever order jsonb keeps keys in',
      () {
    // Grenade first, then mine: jsonb returns "mine" (4 letters) first.
    final library = edit(
      edit(SkillLibrary.defaults, PowerUpKind.grenade),
      PowerUpKind.mine,
    );
    final stored = jsonbOrder(jsonDecode(jsonEncode(library.toJson())));

    expect(library.matchesStored(stored), isTrue);
  });

  test('a library does not match a stored copy with different skills', () {
    final library = edit(SkillLibrary.defaults, PowerUpKind.grenade);
    final other = edit(SkillLibrary.defaults, PowerUpKind.mine);

    expect(
      library.matchesStored(jsonDecode(jsonEncode(other.toJson()))),
      isFalse,
    );
    expect(library.matchesStored(null), isFalse);
  });
}
