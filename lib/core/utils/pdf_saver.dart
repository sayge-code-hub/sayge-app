import 'dart:typed_data';

import 'pdf_saver_io.dart'
    if (dart.library.html) 'pdf_saver_web.dart' as impl;

Future<void> savePdfBytes({
  required Uint8List bytes,
  required String filename,
}) {
  return impl.savePdfBytes(bytes: bytes, filename: filename);
}
