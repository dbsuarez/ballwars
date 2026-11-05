// Web-only local diagnostic; no accounts, uploads, or match data are accessed.
import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ballwars/core/sprites/sprite_registry.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/ball_management/data/local_ball_repository.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';

@JS('window.__ballwarsStartupReport')
external set startupReport(JSString value);
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('Local startup diagnostic'))),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 100));
  final report = <String, Object>{};
  final watch = Stopwatch()..start();
  final serial = Uri.base.queryParameters['serial'] == '1';
  await SpriteRegistry.load(bundle: serial ? _SerialBundle() : rootBundle);
  report['bundledRegistryReadyMs'] = watch.elapsedMilliseconds;
  report['serializedRequests'] = serial;
  report['spriteProblems'] = SpriteRegistry.loadProblems;
  final simulations = <Map<String, Object>>[];
  for (final (mode, race) in [
    (MatchMode.threads, false),
    (MatchMode.threadGrowth, true),
    (MatchMode.arsenal, false),
  ]) {
    watch.reset();
    final match = MatchSimulationController(
      LocalBallRepository.presets.take(2).toList(),
      arenaRadius: 200,
      seed: 34,
      simulationRevision: 10,
      mode: mode,
      threadCutRace: race,
    );
    simulations.add({
      'mode': mode.id,
      'cutRace': race,
      'constructorMs': watch.elapsedMilliseconds,
      'initialStep': match.state.step,
    });
  }
  report['simulations'] = simulations;
  final encoded = jsonEncode(report);
  startupReport = encoded.toJS;
  debugPrint('STARTUP_PROFILE $encoded');
}

class _SerialBundle extends CachingAssetBundle {
  Future<void> tail = Future<void>.value();
  @override
  Future<ByteData> load(String key) {
    final read = tail.then((_) => rootBundle.load(key));
    tail = read.then<void>((_) {}, onError: (Object _) {});
    return read;
  }
}
