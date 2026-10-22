import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'offline_store.dart';

/// `window.ballwarsStore` from `web/offline_store.js`.
@JS('ballwarsStore')
external _BallwarsStore? get _api;

extension type _BallwarsStore._(JSObject _) implements JSObject {
  external bool supported();
  external JSPromise<JSUint8Array?> get(String key);
  external JSPromise<JSAny?> put(String key, JSUint8Array bytes);
  external JSPromise<JSArray<JSString>> missing(JSArray<JSString> keys);
}

OfflineStore? createPlatformStore() {
  final api = _api;
  return api != null && api.supported() ? WebOfflineStore._(api) : null;
}

/// The browser's Cache Storage (survives reloads and works offline).
class WebOfflineStore implements OfflineStore {
  final _BallwarsStore _store;

  WebOfflineStore._(this._store);

  static JSArray<JSString> _list(Iterable<String> keys) => [for (final k in keys) k.toJS].toJS;

  @override
  Future<Uint8List?> read(String key) async => (await _store.get(key).toDart)?.toDart;

  @override
  Future<void> write(String key, Uint8List bytes) => _store.put(key, bytes.toJS).toDart;

  @override
  Future<Set<String>> missing(Iterable<String> keys) async =>
      {for (final k in (await _store.missing(_list(keys)).toDart).toDart) k.toDart};
}
