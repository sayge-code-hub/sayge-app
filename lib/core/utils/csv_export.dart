import 'dart:convert';
import 'dart:typed_data';

import 'pdf_saver.dart';

/// CSV helpers for list exports (Excel-friendly UTF-8 with BOM).
abstract final class CsvExport {
  /// Escape a single cell for RFC-style CSV.
  static String cell(Object? value) {
    final raw = value?.toString() ?? '';
    if (raw.contains(',') ||
        raw.contains('"') ||
        raw.contains('\n') ||
        raw.contains('\r')) {
      return '"${raw.replaceAll('"', '""')}"';
    }
    return raw;
  }

  /// Build a CSV string from [headers] and [rows].
  static String build({
    required List<String> headers,
    required List<List<Object?>> rows,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(headers.map(cell).join(','));
    for (final row in rows) {
      buffer.writeln(row.map(cell).join(','));
    }
    return buffer.toString();
  }

  /// Save CSV via the same download path as PDFs.
  static Future<void> download({
    required String filename,
    required List<String> headers,
    required List<List<Object?>> rows,
  }) {
    final csv = build(headers: headers, rows: rows);
    final bytes = Uint8List.fromList(utf8.encode('\uFEFF$csv'));
    return saveDownloadBytes(
      bytes: bytes,
      filename: filename.endsWith('.csv') ? filename : '$filename.csv',
      mimeType: 'text/csv',
    );
  }
}
