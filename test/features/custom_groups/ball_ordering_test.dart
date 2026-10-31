import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M4 ball queries have a deterministic tie breaker', () {
    final source = File('lib/features/custom_groups/data/custom_group_repository.dart')
        .readAsStringSync();
    final positions = RegExp(r"\.order\('position', referencedTable: 'group_balls'\)")
        .allMatches(source).length;
    final tieBreakers = RegExp(r"\.order\('id', referencedTable: 'group_balls'\)")
        .allMatches(source).length;
    expect(positions, greaterThan(0));
    expect(tieBreakers, positions);
    expect(source, contains('DateTime.now().millisecondsSinceEpoch;'));
  });
}
