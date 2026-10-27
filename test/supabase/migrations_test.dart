import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('migration regex patterns only use repetition counts Postgres accepts (at most 255)', () {
    // Postgres rejects counts above 255 (RE_DUP_MAX) only when the check runs, i.e. on insert, so a bad
    // pattern slips through the SQL editor and breaks the feature later (migration 011 -> 021).
    final count = RegExp(r'\{(\d+)(?:,(\d*))?\}');
    final problems = <String>[];
    for (final file in Directory('supabase/migrations').listSync().whereType<File>()) {
      if (!file.path.endsWith('.sql')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('--')) continue;
        for (final m in count.allMatches(line)) {
          final numbers = [m.group(1), m.group(2)].whereType<String>().where((n) => n.isNotEmpty).map(int.parse);
          if (numbers.any((n) => n > 255)) problems.add('${file.path}:${i + 1}: ${m.group(0)}');
        }
      }
    }
    expect(problems, isEmpty);
  });
}
