import 'dart:convert';
import 'dart:typed_data';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/core/offline/persistent_preferences_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preferences and settings survive replacement of the resource cache', () async {
    final durable = <String, Uint8List>{};
    PersistentPreferencesStore open(OfflineStore cache) => PersistentPreferencesStore(
      resources: cache,
      readPersistent: (key) async => durable[key],
      writePersistent: (key, value) async { durable[key] = value; },
    );
    final first = open(MemoryOfflineStore());
    await first.write('pref:admin-session', utf8.encode('remembered session'));
    await first.write('settings', utf8.encode('{"power_ups":{"dmg.pistol":23}}'));
    await first.write('image.png', Uint8List.fromList([1]));
    final deployed = open(MemoryOfflineStore());
    expect(utf8.decode((await deployed.read('pref:admin-session'))!), 'remembered session');
    expect(utf8.decode((await deployed.read('settings'))!), contains('23'));
    expect(await deployed.read('image.png'), isNull);
  });

  test('legacy values migrate and an empty logout value stays empty', () async {
    final cache = MemoryOfflineStore();
    await cache.write('pref:admin-session', utf8.encode('legacy'));
    final durable = <String, Uint8List>{};
    final store = PersistentPreferencesStore(
      resources: cache,
      readPersistent: (key) async => durable[key],
      writePersistent: (key, value) async { durable[key] = value; },
    );
    expect(utf8.decode((await store.read('pref:admin-session'))!), 'legacy');
    expect(durable, contains('pref:admin-session'));
    await store.write('pref:admin-session', Uint8List(0));
    expect(await store.read('pref:admin-session'), isEmpty);
  });
}
