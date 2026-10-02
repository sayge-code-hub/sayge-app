// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> savePdfBytes({
  required Uint8List bytes,
  required String filename,
}) async {
  final safeName = filename.replaceAll(RegExp(r'[^\w.\-]+'), '_');
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = safeName
    ..style.display = 'none';

  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();

  // Revoke after the browser has started the download.
  await Future<void>.delayed(const Duration(milliseconds: 250));
  html.Url.revokeObjectUrl(url);
}
