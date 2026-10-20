import 'package:flutter/material.dart';
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
