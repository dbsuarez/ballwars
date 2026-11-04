import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<bool> saveReplayFile(Uint8List bytes, String name) async {
  final mobile = Platform.isAndroid || Platform.isIOS;
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Save Ball Wars replay',
    fileName: name,
    type: FileType.custom,
    allowedExtensions: ['bw'],
    bytes: mobile ? bytes : null,
  );
  if (path == null) return false;
  if (!mobile) await File(path).writeAsBytes(bytes, flush: true);
  return true;
}
