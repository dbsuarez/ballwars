import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'offline_store.dart';

OfflineStore? createPlatformStore() => FileOfflineStore();

/// One file per key in `<app support dir>/offline`, named by a hash of the
/// key. That folder belongs to the app and is removed with it.
class FileOfflineStore implements OfflineStore {
  final Future<Directory> _dir = getApplicationSupportDirectory().then(
    (d) => Directory('${d.path}${Platform.pathSeparator}offline').create(recursive: true),
  );

  Future<File> _file(String key) async => File('${(await _dir).path}${Platform.pathSeparator}${_name(key)}');

  /// 64-bit FNV-1a of the key, as hex.
  static String _name(String key) {
    var h = 0xcbf29ce484222325;
    for (final b in utf8.encode(key)) {
      h ^= b;
      h *= 0x100000001b3;
    }
    return h.toUnsigned(64).toRadixString(16).padLeft(16, '0');
  }

  @override
  Future<Uint8List?> read(String key) async {
    final file = await _file(key);
    try {
      return await file.readAsBytes();
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> write(String key, Uint8List bytes) async {
    final file = await _file(key);
    // Write then rename, so a half-written file is never read back.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(file.path);
  }

  @override
  Future<Set<String>> missing(Iterable<String> keys) async {
    final dir = await _dir;
    final present = {
      await for (final e in dir.list())
        if (e is File) e.uri.pathSegments.last,
    };
    return {
      for (final k in keys)
        if (!present.contains(_name(k))) k,
    };
  }
}
