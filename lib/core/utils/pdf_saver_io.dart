import 'dart:typed_data';

import 'package:printing/printing.dart';

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
  // Mobile/desktop: reuse the PDF share sheet; filename extension carries type.
  return Printing.sharePdf(bytes: bytes, filename: filename);
}
