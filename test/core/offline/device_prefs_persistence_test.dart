import 'dart:typed_data';
import 'package:ballwars/core/offline/device_prefs.dart';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _RacingStore extends MemoryOfflineStore {
  int active = 0;
  int peak = 0;

  @override
  Future<void> write(String key, Uint8List bytes) async {
    active++;
    if (active > peak) peak = active;
    await Future<void>.delayed(Duration.zero);
    await super.write(key, bytes);
    active--;
  }
}

void main() {
  test('session writes are ordered and reads wait for the latest save', () async {
    final store = _RacingStore();
    OfflineStore.instance = store;
    final writes = [
      DevicePrefs.write('admin-session', 'old'),
      DevicePrefs.write('admin-session', 'refreshed'),
      DevicePrefs.write('admin-remember-me', '1'),
    ];
    expect(await DevicePrefs.read('admin-session'), 'refreshed');
    await Future.wait(writes);
    expect(store.peak, 1);
    expect(await DevicePrefs.read('admin-remember-me'), '1');
    OfflineStore.instance = MemoryOfflineStore();
  });
}
