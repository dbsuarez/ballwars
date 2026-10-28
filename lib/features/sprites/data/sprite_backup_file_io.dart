import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<bool> saveSpriteBackupFile(Uint8List bytes, String name) async {
  final mobile = Platform.isAndroid || Platform.isIOS;
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Save sprite backup',
    fileName: name,
    type: FileType.custom,
    allowedExtensions: ['bwsprites'],
    bytes: mobile ? bytes : null,
  );
  if (path == null) return false;
  if (!mobile) await File(path).writeAsBytes(bytes, flush: true);
  return true;
}
