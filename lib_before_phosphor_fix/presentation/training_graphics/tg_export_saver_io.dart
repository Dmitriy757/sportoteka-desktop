import 'dart:io';
import 'dart:typed_data';

Future<String> saveTgExportFile(
  String fileName,
  Uint8List bytes, {
  String mimeType = 'application/octet-stream',
  String? folderName,
}) async {
  final safeFolder = (folderName == null || folderName.trim().isEmpty)
      ? 'sportoteka_training_export'
      : folderName.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_\-а-яА-Я ]'), '_');
  final dir = Directory('${Directory.systemTemp.path}/$safeFolder');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  final safeFile = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  final file = File('${dir.path}/$safeFile');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
