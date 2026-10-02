/// Shared document-number series helpers (invoices / proposals).
///
/// Patterns:
/// - Invoice: `INV-SY/{yy}/{n}` (year-scoped sequence)
/// - Proposal: `QT-SY/{yy}/{n}` (sequence continues from legacy `QT-{n}-{yymmdd}`)
abstract final class DocumentSeries {
  static final _invoiceYearSeq = RegExp(
    r'^INV-SY/(\d{2})/(\d+)$',
    caseSensitive: false,
  );
  static final _proposalNewSeq = RegExp(
    r'^QT-SY/\d{2}/(\d+)$',
    caseSensitive: false,
  );
  static final _proposalLegacySeq = RegExp(
    r'^QT-(\d+)-\d{6}$',
    caseSensitive: false,
  );

  static String _yy(DateTime at) =>
      (at.year % 100).toString().padLeft(2, '0');

  static int _maxSeq(Iterable<String> values, Iterable<RegExp> patterns) {
    var max = 0;
    for (final raw in values) {
      final value = raw.trim();
      if (value.isEmpty) continue;
      for (final pattern in patterns) {
        final match = pattern.firstMatch(value);
        if (match == null) continue;
        final n = int.tryParse(match.group(match.groupCount)!) ?? 0;
        if (n > max) max = n;
      }
    }
    return max;
  }

  /// Next invoice number: `INV-SY/{yy}/{max+1}` for [at]'s year.
  static String nextInvoiceNo({
    required Iterable<String> existing,
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();
    final yy = _yy(now);
    final yearOnly = RegExp(
      '^INV-SY/$yy/(\\d+)\$',
      caseSensitive: false,
    );
    final max = _maxSeq(existing, [yearOnly]);
    return 'INV-SY/$yy/${max + 1}';
  }

  /// Next proposal number: `QT-SY/{yy}/{max+1}`.
  ///
  /// Sequence considers both the new format and legacy `QT-{n}-{yymmdd}`
  /// so numbering continues past e.g. `QT-36-250926` → `QT-SY/26/37`.
  static String nextProposalNo({
    required Iterable<String> existing,
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();
    final yy = _yy(now);
    final max = _maxSeq(existing, [_proposalNewSeq, _proposalLegacySeq]);
    return 'QT-SY/$yy/${max + 1}';
  }

  /// Case-insensitive exact match against existing numbers.
  static bool isTaken(String candidate, Iterable<String> existing) {
    final needle = candidate.trim().toLowerCase();
    if (needle.isEmpty) return false;
    for (final value in existing) {
      if (value.trim().toLowerCase() == needle) return true;
    }
    return false;
  }

  /// Exposed for tests / diagnostics.
  static int invoiceSeqForYear(String value, String yy) {
    final match = _invoiceYearSeq.firstMatch(value.trim());
    if (match == null) return 0;
    if (match.group(1) != yy) return 0;
    return int.tryParse(match.group(2)!) ?? 0;
  }
}
