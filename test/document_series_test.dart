import 'package:flutter_test/flutter_test.dart';

import 'package:sayge_app/core/utils/document_series.dart';

void main() {
  group('DocumentSeries.nextInvoiceNo', () {
    test('increments year-scoped sequence', () {
      final next = DocumentSeries.nextInvoiceNo(
        existing: const ['INV-SY/26/36', 'INV-SY/25/99'],
        at: DateTime(2026, 10, 3),
      );
      expect(next, 'INV-SY/26/37');
    });

    test('starts at 1 when year has no invoices', () {
      final next = DocumentSeries.nextInvoiceNo(
        existing: const ['INV-SY/25/10'],
        at: DateTime(2026, 1, 1),
      );
      expect(next, 'INV-SY/26/1');
    });
  });

  group('DocumentSeries.nextProposalNo', () {
    test('continues past legacy QT-n-yymmdd', () {
      final next = DocumentSeries.nextProposalNo(
        existing: const ['QT-36-250926'],
        at: DateTime(2026, 10, 3),
      );
      expect(next, 'QT-SY/26/37');
    });

    test('continues past new QT-SY format', () {
      final next = DocumentSeries.nextProposalNo(
        existing: const ['QT-SY/26/37', 'QT-36-250926'],
        at: DateTime(2026, 10, 3),
      );
      expect(next, 'QT-SY/26/38');
    });
  });

  group('DocumentSeries.isTaken', () {
    test('matches case-insensitively', () {
      expect(
        DocumentSeries.isTaken('inv-sy/26/36', const ['INV-SY/26/36']),
        isTrue,
      );
      expect(
        DocumentSeries.isTaken('INV-SY/26/37', const ['INV-SY/26/36']),
        isFalse,
      );
    });
  });
}
