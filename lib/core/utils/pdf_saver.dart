import 'dart:typed_data';

import 'pdf_saver_io.dart'
    if (dart.library.html) 'pdf_saver_web.dart' as impl;

Future<void> savePdfBytes({
  required Uint8List bytes,
  required String filename,
}) {
  return saveDownloadBytes(
    bytes: bytes,
    filename: filename,
    mimeType: 'application/pdf',
  );
}

Future<void> saveDownloadBytes({
  required Uint8List bytes,
  required String filename,
  String mimeType = 'application/octet-stream',
}) {
  return impl.saveDownloadBytes(
    bytes: bytes,
    filename: filename,
    mimeType: mimeType,
  );
}
