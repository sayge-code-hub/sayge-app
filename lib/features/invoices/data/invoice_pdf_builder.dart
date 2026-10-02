import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/config/app_display_config.dart';
import '../../../../core/config/app_invoice_config.dart';
import '../domain/entities/invoice.dart';

abstract final class InvoicePdfBuilder {
  static final _number = NumberFormat.decimalPattern(AppDisplayConfig.locale);
  static final _date = DateFormat('d-MMM-yy');

  static String _money(num value) => _number.format(value.round());

  static String _safe(String text) {
    return text
        .replaceAll('₹', 'Rs.')
        .replaceAll('•', '-')
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('\u00A0', ' ');
  }

  static Future<pw.MemoryImage?> _load(String path) async {
    try {
      final data = await rootBundle.load(path);
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  static Future<pw.Document> build(Invoice invoice) async {
    final logo = await _load(AppInvoiceConfig.logoAsset);
    final signature = await _load(AppInvoiceConfig.signatureAsset);

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
        build: (_) => [
          _titleBar(),
          pw.SizedBox(height: 10),
          _companyHeader(logo),
          pw.SizedBox(height: 8),
          pw.Container(height: 4, color: PdfColor.fromHex('#1E3A5F')),
          pw.SizedBox(height: 0),
          _buyerAndMeta(invoice),
          pw.SizedBox(height: 0),
          _lineTable(invoice),
          _taxAndTotals(invoice),
          pw.SizedBox(height: 0),
          _footer(invoice, signature),
        ],
      ),
    );
    return doc;
  }

  static pw.Widget _titleBar() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey700, width: 0.8),
      ),
      child: pw.Center(
        child: pw.Text(
          AppInvoiceConfig.documentTitle,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
      ),
    );
  }

  static pw.Widget _companyHeader(pw.MemoryImage? logo) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey700, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.4),
        1: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    AppInvoiceConfig.companyName,
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    _safe(AppInvoiceConfig.companyAddress),
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    'GSTIN: ${AppInvoiceConfig.companyGstin}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    'PAN: ${AppInvoiceConfig.companyPan}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    'SAC Code: ${AppInvoiceConfig.sacCode}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    'Tel: ${AppInvoiceConfig.companyTel}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    'Email: ${AppInvoiceConfig.companyEmail}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Align(
                alignment: pw.Alignment.topRight,
                child: logo != null
                    ? pw.Image(logo, height: 36)
                    : pw.SizedBox(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buyerAndMeta(Invoice invoice) {
    final buyerTitle = invoice.buyerCompany.isNotEmpty
        ? invoice.buyerCompany
        : invoice.buyerName;

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey700, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.4),
        1: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Buyer Name',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          _safe(buyerTitle),
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  if (invoice.buyerAddress.isNotEmpty)
                    pw.Text(
                      _safe(invoice.buyerAddress),
                      style: const pw.TextStyle(fontSize: 8, lineSpacing: 1.5),
                    ),
                  pw.SizedBox(height: 6),
                  _kv('Place of Supply', invoice.placeOfSupply),
                  _kv('GSTIN of the buyer', invoice.buyerGstin),
                  _kv(
                    'Contact Person',
                    invoice.buyerContact.isNotEmpty
                        ? invoice.buyerContact
                        : invoice.buyerName,
                  ),
                ],
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _kv('Invoice No.', invoice.invoiceNo),
                  _kv('Date', _date.format(invoice.invoiceDate)),
                  _kv(
                    'P.O.Number',
                    invoice.poNumber.isEmpty ? '-' : invoice.poNumber,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _kv(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label : ',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
            pw.TextSpan(
              text: _safe(value.isEmpty ? '-' : value),
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _lineTable(Invoice invoice) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey700, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(0.5),
        1: pw.FlexColumnWidth(3.2),
        2: pw.FlexColumnWidth(1),
        3: pw.FlexColumnWidth(1.2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _cell('Sr. No.', bold: true, align: pw.TextAlign.center),
            _cell('Particulars', bold: true),
            _cell('Taxes', bold: true, align: pw.TextAlign.center),
            _cell('Amount (In Rupees)', bold: true, align: pw.TextAlign.right),
          ],
        ),
        for (var i = 0; i < invoice.lineItems.length; i++)
          pw.TableRow(
            children: [
              _cell('${i + 1}', align: pw.TextAlign.center),
              _cell(_safe(invoice.lineItems[i].particulars)),
              _cell(''),
              _cell(
                _money(invoice.lineItems[i].amount),
                align: pw.TextAlign.right,
              ),
            ],
          ),
        if (invoice.lineItems.isEmpty)
          pw.TableRow(
            children: [
              _cell(''),
              _cell(''),
              _cell(''),
              _cell(''),
            ],
          ),
      ],
    );
  }

  static pw.Widget _taxAndTotals(Invoice invoice) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey700, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(4.7),
        1: pw.FlexColumnWidth(1.2),
      },
      children: [
        _taxRow(
          'CGST-${AppInvoiceConfig.cgstRate.toStringAsFixed(0)}%',
          invoice.cgstAmount > 0 ? _money(invoice.cgstAmount) : '',
        ),
        _taxRow(
          'SGST-${AppInvoiceConfig.sgstRate.toStringAsFixed(0)}%',
          invoice.sgstAmount > 0 ? _money(invoice.sgstAmount) : '',
        ),
        _taxRow(
          'IGST-${AppInvoiceConfig.igstRate.toStringAsFixed(0)}%',
          invoice.igstAmount > 0 ? _money(invoice.igstAmount) : '',
        ),
        _taxRow('Total', _money(invoice.totalAmount), bold: true),
      ],
    );
  }

  static pw.TableRow _taxRow(String label, String value, {bool bold = false}) {
    return pw.TableRow(
      children: [
        _cell(label, bold: bold, align: pw.TextAlign.right),
        _cell(value, bold: bold, align: pw.TextAlign.right),
      ],
    );
  }

  static pw.Widget _footer(Invoice invoice, pw.MemoryImage? signature) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey700, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.3),
        1: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Amount Chargeable (in words)',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Center(
                    child: pw.Text(
                      _safe(invoice.amountInWords),
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    'Declaration',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    _safe(AppInvoiceConfig.declaration),
                    style: const pw.TextStyle(fontSize: 7, lineSpacing: 1.4),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Center(
                    child: pw.Text(
                      AppInvoiceConfig.gratitudeLine,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                ],
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('E. & O.E', style: const pw.TextStyle(fontSize: 8)),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    "Company's Bank Details",
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  _kv('Bank Name', AppInvoiceConfig.bankName),
                  _kv('A/c No.', AppInvoiceConfig.bankAccountNo),
                  _kv('Branch', AppInvoiceConfig.bankBranch),
                  _kv('IFSC Code', AppInvoiceConfig.bankIfsc),
                  pw.SizedBox(height: 10),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        if (signature != null)
                          pw.Image(
                            signature,
                            width: 58,
                            height: 60,
                            fit: pw.BoxFit.contain,
                            dpi: 200,
                          ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          AppInvoiceConfig.authorisedSignatoryLabel,
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _cell(
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Container(
      alignment: switch (align) {
        pw.TextAlign.right => pw.Alignment.centerRight,
        pw.TextAlign.center => pw.Alignment.center,
        _ => pw.Alignment.centerLeft,
      },
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}
