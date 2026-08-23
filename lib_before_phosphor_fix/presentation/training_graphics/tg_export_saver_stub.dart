import 'dart:typed_data';

Future<String> saveTgExportFile(
  String fileName,
  Uint8List bytes, {
  String mimeType = 'application/octet-stream',
  String? folderName,
}) async {
  throw UnsupportedError('Экспорт файлов не поддерживается на этой платформе');
}
