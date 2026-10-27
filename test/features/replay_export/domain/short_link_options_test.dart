import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/replay_export/domain/replay_document.dart';

void main() {
  test('versioned replay documents retain every modern match option', () {
    final query = <String, String>{
      'seed': '42',
      'balls': 'p.a,p.b',
      'mayhem': '1',
      'duration': '120',
      'endless': '1',
      'dw': '1',
      'shrink': '1',
      'hair': '1',
      'skills': 'custom-skill-snapshot',
      'arena': 'chaotic',
    };
    expect(ReplayDocument.decode(ReplayDocument(query).encode()).query, query);
  });
  test('replay files reject invalid versions and oversized payloads', () {
    expect(
      () => ReplayDocument.fromJson({'version': 99}),
      throwsFormatException,
    );
    expect(
      () => ReplayDocument({'seed': 'no', 'balls': 'p.a,p.b'}),
      throwsFormatException,
    );
    expect(
      () => ReplayDocument({
        'seed': '42',
        'balls': 'x' * ReplayDocument.maxBytes,
      }),
      throwsFormatException,
    );
  });
}
