import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/config/app_display_config.dart';
import '../domain/entities/cafe_entities.dart';

abstract final class CafeReceiptPdf {
  static final _money = NumberFormat.decimalPattern(AppDisplayConfig.locale);
  static final _when = DateFormat('d MMM yyyy, h:mm a');

  static String _m(num v) => 'Rs. ${_money.format(v)}';

  static Future<pw.Document> build(
    CafeOrder order, {
    String cafeName = 'Cafe',
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(12),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              cafeName,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Receipt',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 11),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Order ${order.orderNo}', style: const pw.TextStyle(fontSize: 10)),
            pw.Text(
              [
                if (order.tableNo.trim().isNotEmpty)
                  'Table ${order.tableNo.trim()}',
                order.orderType.label,
                _when.format(order.createdAt.toLocal()),
              ].join(' · '),
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 8),
            pw.Divider(),
            for (final item in order.items) ...[
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      '${item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 1)} x ${item.itemName}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                  pw.Text(
                    _m(item.lineTotal),
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
              if (item.notes.trim().isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 8, bottom: 2),
                  child: pw.Text(
                    item.notes,
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                ),
            ],
            pw.Divider(),
            _row('Subtotal', _m(order.subtotal)),
            if (order.taxAmount > 0) _row('GST', _m(order.taxAmount)),
            if (order.discountAmount > 0)
              _row(
                order.couponCode.isNotEmpty
                    ? 'Discount (${order.couponCode})'
                    : 'Discount',
                '- ${_m(order.discountAmount)}',
              ),
            _row('Total', _m(order.totalAmount), bold: true),
            pw.SizedBox(height: 6),
            pw.Text(
              'Payment: ${order.paymentStatus.label}',
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Thank you',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
      ),
    );
    return doc;
  }

  static pw.Widget _row(String label, String value, {bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: 10,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Text(label, style: style)),
          pw.Text(value, style: style),
        ],
      ),
    );
  }
}
