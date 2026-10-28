import 'dart:js_interop';
import 'dart:typed_data';

@JS('ballwarsSpriteBackup.download')
external void _download(JSUint8Array bytes, JSString name);
Future<bool> saveSpriteBackupFile(Uint8List bytes, String name) async {
  _download(bytes.toJS, name.toJS);
  return true;
}
