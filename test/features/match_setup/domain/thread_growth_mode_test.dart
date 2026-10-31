import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';

void main() {
  test('Thread Growth is a distinct selectable thread-only match mode', () {
    expect(MatchMode.threadGrowth, isNot(MatchMode.threads));
    expect(MatchMode.threadGrowth.label, 'Thread Growth');
    expect(MatchMode.threadGrowth.isThreadOnly, isTrue);
    expect(MatchMode.byId('threadgrowth'), MatchMode.threadGrowth);
    expect(MatchMode.arsenal.isThreadOnly, isFalse);
  });
}
