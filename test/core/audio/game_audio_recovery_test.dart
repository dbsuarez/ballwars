import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/audio/game_audio.dart';
import 'package:ballwars/core/offline/offline_store.dart';

class _Player extends Fake implements AudioPlayer {
  final calls = <String>[];
  bool fail = false;
  Completer<void>? blocked;
  @override
  PlayerState get state => PlayerState.stopped;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final method = invocation.memberName;
    if (method == #play) {
      calls.add((invocation.positionalArguments.first as AssetSource).path);
      if (fail) return Future<void>.error(StateError('lost native handle'));
      return blocked?.future ?? Future<void>.value();
    }
    if (method == #stop) calls.add('stop');
    if (method == #pause) calls.add('pause');
    if (method == #dispose) calls.add('dispose');
    return Future<void>.value();
  }
}

Future<void> _flush() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.value();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final audio = GameAudio.instance;
  final players = <_Player>[];
  setUp(() async {
    OfflineStore.instance = MemoryOfflineStore();
    audio.enabled = true;
    audio.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await audio.setEffectsOn(true);
    players.clear();
    GameAudio.playerFactory = () {
      final p = _Player();
      players.add(p);
      return p;
    };
  });
  tearDown(() async {
    audio.enabled = false;
    audio.resetEffects();
    await _flush();
    GameAudio.playerFactory = null;
  });

  test(
    'restart restores bounce without relying on a previous player',
    () async {
      audio.bounce();
      await _flush();
      expect(players.single.calls, contains('sounds/bounce.wav'));
      final old = players.single;
      audio.resetEffects();
      audio.bounce();
      await _flush();
      expect(old.calls, contains('dispose'));
      expect(players.last, isNot(same(old)));
      expect(players.last.calls, contains('sounds/bounce.wav'));
    },
  );

  test('failed sound handle is replaced on the next event', () async {
    GameAudio.playerFactory = () {
      final p = _Player()..fail = players.isEmpty;
      players.add(p);
      return p;
    };
    audio.whistle();
    await _flush();
    audio.whistle();
    await _flush();
    expect(players, hasLength(2));
    expect(players.first.calls, contains('dispose'));
    expect(players.last.calls, contains('sounds/whistle.wav'));
  });

  test(
    'background suppresses effects and return creates fresh bounce players',
    () async {
      audio.bounce();
      await _flush();
      audio.didChangeAppLifecycleState(AppLifecycleState.hidden);
      audio.whistle();
      await _flush();
      expect(players, hasLength(1));
      audio.didChangeAppLifecycleState(AppLifecycleState.resumed);
      audio.bounce();
      await _flush();
      expect(players, hasLength(2));
      expect(players.last.calls, contains('sounds/bounce.wav'));
    },
  );

  test(
    'busy players do not receive overlapping play commands and recover capacity',
    () async {
      final blocked = Completer<void>();
      GameAudio.playerFactory = () {
        final p = _Player()..blocked = blocked;
        players.add(p);
        return p;
      };
      for (var i = 0; i < 4; i++) {
        audio.whistle();
      }
      await _flush();
      expect(players, hasLength(3));
      expect(players.every((p) => p.calls.length == 1), isTrue);
      blocked.complete();
      await _flush();
      audio.whistle();
      await _flush();
      expect(players.fold<int>(0, (count, p) => count + p.calls.length), 4);
    },
  );

  test(
    'admin skill preview plays even when effects are switched off',
    () async {
      await audio.setEffectsOn(false);
      audio.previewSkillCue('bomb');
      await _flush();

      expect(players.single.calls, contains('sounds/bomb.wav'));
    },
  );

  test(
    'rapid stop and new match start leave music playing after the stop',
    () async {
      audio.startMusic();
      await _flush();
      audio.stopMusic();
      audio.startMusic();
      await _flush();
      final calls = players.single.calls;
      expect(calls.last, startsWith('sounds/bgm_'));
      expect(calls.indexOf('stop'), lessThan(calls.length - 1));
      audio.stopMusic();
      await _flush();
    },
  );
}
