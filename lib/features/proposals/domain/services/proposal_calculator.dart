import '../../../../core/config/app_proposal_config.dart';
import '../../../../core/utils/document_series.dart';
import '../../../../core/utils/indian_number_to_words.dart';
import '../entities/proposal.dart';

abstract final class ProposalCalculator {
  /// Total = monthlyRate * months (+ days portion if months=0 and days>0).
  /// When both months and days are set, uses months * monthlyRate
  /// (days are informational, matching the sample slip).
  static double lineTotal({
    required double monthlyRate,
    required int months,
    required int days,
  }) {
    if (months > 0) {
      return _round(monthlyRate * months);
    }
    if (days > 0) {
      return _round(monthlyRate * days / 30);
    }
    return 0;
  }

  static double subtotal(List<ProposalLineItem> lines) {
    return _round(lines.fold<double>(0, (sum, line) => sum + line.totalRate));
  }

  static String amountInWords(num amount) {
    final words = IndianNumberToWords.convert(amount);
    // Sample uses lowercase "only" style: "Two lakh fifty two thousand only"
    if (words.endsWith(' Only')) {
      return '${words.substring(0, words.length - 5)} only';
    }
    return words.toLowerCase();
  }

  static String generateReferenceNo({
    required Iterable<String> existing,
    DateTime? at,
  }) {
    return DocumentSeries.nextProposalNo(existing: existing, at: at);
  }

  static bool isReferenceNoTaken(
    String referenceNo,
    Iterable<String> existing,
  ) {
    return DocumentSeries.isTaken(referenceNo, existing);
  }

  static DateTime defaultExpiry(DateTime quoteDate) {
    return quoteDate.add(
      const Duration(days: AppProposalConfig.defaultValidityDays),
    );
  }

  static String defaultNotesText() {
    return AppProposalConfig.defaultNotes.map((n) => '- $n').join('\n');
  }

  static double _round(double value) => value.roundToDouble();
}
