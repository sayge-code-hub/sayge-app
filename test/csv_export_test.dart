import 'package:flutter_test/flutter_test.dart';
import 'package:sayge_app/core/utils/csv_export.dart';

void main() {
  group('CsvExport', () {
    test('escapes commas and quotes', () {
      expect(CsvExport.cell('plain'), 'plain');
      expect(CsvExport.cell('a,b'), '"a,b"');
      expect(CsvExport.cell('say "hi"'), '"say ""hi"""');
      expect(CsvExport.cell('line\nbreak'), '"line\nbreak"');
    });

    test('build writes header and rows', () {
      final csv = CsvExport.build(
        headers: const ['Name', 'Amount'],
        rows: const [
          ['Acme, Inc', 1200],
          ['Beta', 50.5],
        ],
      );
      expect(csv, contains('Name,Amount'));
      expect(csv, contains('"Acme, Inc",1200'));
      expect(csv, contains('Beta,50.5'));
    });
  });
}
