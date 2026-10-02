import '../../../../core/config/app_invoice_config.dart';
import '../../../../core/utils/document_series.dart';
import '../../../../core/utils/indian_number_to_words.dart';
import '../entities/invoice.dart';

class InvoiceTaxBreakdown {
  const InvoiceTaxBreakdown({
    required this.taxable,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.total,
  });

  final double taxable;
  final double cgst;
  final double sgst;
  final double igst;
  final double total;
}

abstract final class InvoiceCalculator {
  static double _round(double value) => value.roundToDouble();

  static double taxableAmount(List<InvoiceLineItem> lines) {
    return _round(lines.fold<double>(0, (sum, line) => sum + line.amount));
  }

  static InvoiceTaxBreakdown taxes({
    required double taxable,
    required bool intraState,
  }) {
    if (intraState) {
      final cgst = _round(taxable * AppInvoiceConfig.cgstRate / 100);
      final sgst = _round(taxable * AppInvoiceConfig.sgstRate / 100);
      return InvoiceTaxBreakdown(
        taxable: taxable,
        cgst: cgst,
        sgst: sgst,
        igst: 0,
        total: _round(taxable + cgst + sgst),
      );
    }
    final igst = _round(taxable * AppInvoiceConfig.igstRate / 100);
    return InvoiceTaxBreakdown(
      taxable: taxable,
      cgst: 0,
      sgst: 0,
      igst: igst,
      total: _round(taxable + igst),
    );
  }

  static String amountInWords(num amount) {
    final words = IndianNumberToWords.convert(amount);
    if (words.endsWith(' Only')) {
      return '${words.substring(0, words.length - 5)} Rupees Only';
    }
    if (words.toLowerCase().endsWith(' only')) {
      final base = words.substring(0, words.length - 5).trim();
      return '$base Rupees Only';
    }
    return '$words Rupees Only';
  }

  static String generateInvoiceNo({
    required Iterable<String> existing,
    DateTime? at,
  }) {
    return DocumentSeries.nextInvoiceNo(existing: existing, at: at);
  }

  static bool isInvoiceNoTaken(String invoiceNo, Iterable<String> existing) {
    return DocumentSeries.isTaken(invoiceNo, existing);
  }
}
