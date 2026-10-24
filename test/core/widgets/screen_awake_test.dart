import 'package:ballwars/core/widgets/screen_awake.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('wake lock follows running state, lifecycle and disposal', (tester) async {
    final requests = <bool>[];
    Future<void> record(bool value) async => requests.add(value);
    Widget app(bool enabled) => MaterialApp(home: ScreenAwake(
      enabled: enabled, setEnabled: record, child: const SizedBox(),
    ));
    await tester.pumpWidget(app(true));
    await tester.pump();
    expect(requests.last, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(requests.last, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(requests.last, isTrue);
    await tester.pumpWidget(app(false));
    await tester.pump();
    expect(requests.last, isFalse);
    await tester.pumpWidget(app(true));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(requests.last, isFalse);
  });
}
