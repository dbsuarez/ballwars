import 'package:ballwars/core/audio/audio_channel_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('long press opens one compact popup for all audio channels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AudioChannelButton(channel: AudioChannel.ux)),
      ),
    );
    await tester.longPress(find.byType(AudioChannelButton));
    await tester.pumpAndSettle();

    expect(find.text('Audio'), findsOneWidget);
    expect(find.text('BGM'), findsOneWidget);
    expect(find.text('SFX'), findsOneWidget);
    expect(find.text('UX'), findsNWidgets(2));
    expect(find.byType(Slider), findsNWidgets(3));
    expect(
      tester.getSize(find.byKey(const ValueKey('audio-popup'))).height,
      lessThan(330),
    );
  });
}
