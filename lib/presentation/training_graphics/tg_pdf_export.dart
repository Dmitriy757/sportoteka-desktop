import 'dart:convert';
import 'dart:typed_data';

/// Builds a single-page landscape PDF from raw RGBA pixels without requiring a
/// third-party PDF package. The image stream is intentionally uncompressed so
/// the helper stays platform-neutral (including Flutter web).
Uint8List buildTgRasterPdf({
  required Uint8List rgba,
  required int pixelWidth,
  required int pixelHeight,
}) {
  if (pixelWidth <= 0 || pixelHeight <= 0) {
    throw ArgumentError('Invalid image dimensions');
  }
  final expected = pixelWidth * pixelHeight * 4;
  if (rgba.lengthInBytes < expected) {
    throw ArgumentError('RGBA buffer is shorter than expected');
  }

  // A4 landscape in PDF points.
  const pageW = 841.89;
  const pageH = 595.28;
  const margin = 20.0;
  final usableW = pageW - margin * 2;
  final usableH = pageH - margin * 2;
  final imageRatio = pixelWidth / pixelHeight;
  final areaRatio = usableW / usableH;
  final drawW = imageRatio >= areaRatio ? usableW : usableH * imageRatio;
  final drawH = drawW / imageRatio;
  final x = (pageW - drawW) / 2;
  final y = (pageH - drawH) / 2;

  final rgb = Uint8List(pixelWidth * pixelHeight * 3);
  var dst = 0;
  for (var src = 0; src < expected; src += 4) {
    final alpha = rgba[src + 3] / 255.0;
    // Composite transparency on white, which matches the editor export.
    rgb[dst++] = (rgba[src] * alpha + 255 * (1 - alpha)).round().clamp(0, 255).toInt();
    rgb[dst++] = (rgba[src + 1] * alpha + 255 * (1 - alpha)).round().clamp(0, 255).toInt();
    rgb[dst++] = (rgba[src + 2] * alpha + 255 * (1 - alpha)).round().clamp(0, 255).toInt();
  }

  final content = ascii.encode(
    'q\n${_n(drawW)} 0 0 ${_n(drawH)} ${_n(x)} ${_n(y)} cm\n/Im0 Do\nQ\n',
  );

  final out = BytesBuilder(copy: false);
  final offsets = <int>[0];
  var length = 0;
  void add(List<int> bytes) {
    out.add(bytes);
    length += bytes.length;
  }
  void addAscii(String s) => add(ascii.encode(s));
  void object(int id, void Function() body) {
    while (offsets.length <= id) offsets.add(0);
    offsets[id] = length;
    addAscii('$id 0 obj\n');
    body();
    addAscii('\nendobj\n');
  }

  addAscii('%PDF-1.4\n%');
  add(const <int>[0xE2, 0xE3, 0xCF, 0xD3, 0x0A]);
  object(1, () => addAscii('<< /Type /Catalog /Pages 2 0 R >>'));
  object(2, () => addAscii('<< /Type /Pages /Kids [3 0 R] /Count 1 >>'));
  object(3, () {
    addAscii(
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${_n(pageW)} ${_n(pageH)}] '
      '/Resources << /XObject << /Im0 4 0 R >> >> /Contents 5 0 R >>',
    );
  });
  object(4, () {
    addAscii(
      '<< /Type /XObject /Subtype /Image /Width $pixelWidth /Height $pixelHeight '
      '/ColorSpace /DeviceRGB /BitsPerComponent 8 /Length ${rgb.length} >>\nstream\n',
    );
    add(rgb);
    addAscii('\nendstream');
  });
  object(5, () {
    addAscii('<< /Length ${content.length} >>\nstream\n');
    add(content);
    addAscii('endstream');
  });

  final xref = length;
  addAscii('xref\n0 6\n0000000000 65535 f \n');
  for (int id = 1; id <= 5; id++) {
    addAscii('${offsets[id].toString().padLeft(10, '0')} 00000 n \n');
  }
  addAscii('trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n');
  return out.takeBytes();
}

String _n(num v) => v.toStringAsFixed(2).replaceFirst(RegExp(r'\.00$'), '');
