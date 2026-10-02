import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/config/app_display_config.dart';
import '../../../../core/config/app_proposal_config.dart';
import '../domain/entities/proposal.dart';

/// Builds proposal PDFs matching the Sayge quote template.
abstract final class ProposalPdfBuilder {
  /// Helvetica cannot render ₹ / • / —; use ASCII-safe money labels.
  static final _number = NumberFormat.decimalPattern(AppDisplayConfig.locale);
  static final _date = DateFormat('MM/dd/yyyy');

  static const _logoAsset = 'assets/images/sayge_logo.png';

  static String _money(num value) => 'Rs. ${_number.format(value.round())}';

  static Future<pw.MemoryImage?> _loadAssetImage(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  static String _safe(String text) {
    return text
        .replaceAll('₹', 'Rs.')
        .replaceAll('•', '-')
        .replaceAll('●', '-')
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('\u00A0', ' ');
  }

  static Future<pw.Document> build(Proposal proposal) async {
    final logo = await _loadAssetImage(_logoAsset);
    final signature = await _loadAssetImage(AppProposalConfig.signatureAsset);

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 36),
        build: (_) => [
          _header(logo),
          pw.SizedBox(height: 16),
          pw.Center(
            child: pw.Text(
              AppProposalConfig.documentTitle,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 14),
          _metaTable(proposal),
          pw.SizedBox(height: 14),
          _parties(proposal),
          pw.SizedBox(height: 14),
          _lineItems(proposal),
          pw.SizedBox(height: 10),
          _totals(proposal),
          pw.SizedBox(height: 24),
          _footer(proposal, signature),
        ],
      ),
    );
    return doc;
  }

  static pw.Widget _footer(Proposal proposal, pw.MemoryImage? signature) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                AppProposalConfig.notesHeading,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.left,
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                _safe(proposal.notes),
                style: const pw.TextStyle(fontSize: 9, lineSpacing: 2),
                textAlign: pw.TextAlign.left,
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 16),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              AppProposalConfig.authorisedSignatureLabel,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
              textAlign: pw.TextAlign.right,
            ),
            pw.SizedBox(height: 6),
            if (signature != null)
              pw.Image(
                signature,
                width: 58,
                height: 60,
                fit: pw.BoxFit.contain,
                dpi: 200,
              )
            else
              pw.SizedBox(height: 60),
          ],
        ),
      ],
    );
  }

  static pw.Widget _header(pw.MemoryImage? logo) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        if (logo != null)
          pw.Image(logo, height: 32)
        else
          pw.Text(
            AppProposalConfig.companyName,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              AppProposalConfig.companyRegion,
              style: const pw.TextStyle(fontSize: 10),
              textAlign: pw.TextAlign.right,
            ),
            pw.Text(
              AppProposalConfig.companyCountry,
              style: const pw.TextStyle(fontSize: 10),
              textAlign: pw.TextAlign.right,
            ),
            pw.Text(
              'GSTIN: ${AppProposalConfig.companyGstin}',
              style: const pw.TextStyle(fontSize: 10),
              textAlign: pw.TextAlign.right,
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _metaTable(Proposal proposal) {
    final rows = <List<String>>[
      [
        'Reference No',
        proposal.referenceNo,
        'Place of Supply',
        proposal.placeOfSupply,
      ],
      [
        'Quote Date',
        _date.format(proposal.quoteDate),
        'Vendor Code',
        proposal.vendorCode.isEmpty ? '-' : proposal.vendorCode,
      ],
      [
        'Expiry Date',
        _date.format(proposal.expiryDate),
        'Entity Code',
        proposal.entityCode.isEmpty ? '-' : proposal.entityCode,
      ],
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.2),
        1: pw.FlexColumnWidth(1.5),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.5),
      },
      children: [
        for (final row in rows)
          pw.TableRow(
            children: [
              for (var i = 0; i < 4; i++)
                _cell(_safe(row[i]), bold: i.isEven),
            ],
          ),
      ],
    );
  }

  static pw.Widget _parties(Proposal proposal) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _partyBlock(
            'Bill To',
            proposal.billToName,
            proposal.billToCompany,
            proposal.billToAddress,
            proposal.billToGstin,
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: _partyBlock(
            'Ship To',
            proposal.shipToName,
            proposal.shipToCompany,
            proposal.shipToAddress,
            proposal.shipToGstin,
          ),
        ),
      ],
    );
  }

  static pw.Widget _partyBlock(
    String title,
    String name,
    String company,
    String address,
    String gstin,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.left,
          ),
          pw.SizedBox(height: 4),
          if (name.isNotEmpty)
            pw.Text(_safe(name), style: const pw.TextStyle(fontSize: 9)),
          if (company.isNotEmpty)
            pw.Text(_safe(company), style: const pw.TextStyle(fontSize: 9)),
          if (address.isNotEmpty)
            pw.Text(_safe(address), style: const pw.TextStyle(fontSize: 9)),
          if (gstin.isNotEmpty)
            pw.Text(
              'GSTIN ${_safe(gstin)}',
              style: const pw.TextStyle(fontSize: 9),
            ),
        ],
      ),
    );
  }

  static pw.Widget _lineItems(Proposal proposal) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(0.6),
        1: pw.FlexColumnWidth(2.4),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.0),
        4: pw.FlexColumnWidth(1.0),
        5: pw.FlexColumnWidth(1.2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _cell('Sr No (#)', bold: true, align: pw.TextAlign.center),
            _cell('Item & Description', bold: true),
            _cell('Monthly Rate', bold: true, align: pw.TextAlign.right),
            _cell('No of Months', bold: true, align: pw.TextAlign.right),
            _cell('No of Days', bold: true, align: pw.TextAlign.right),
            _cell('Total Rate', bold: true, align: pw.TextAlign.right),
          ],
        ),
        for (var i = 0; i < proposal.lineItems.length; i++)
          pw.TableRow(
            children: [
              _cell('${i + 1}', align: pw.TextAlign.center),
              _cell(_safe(proposal.lineItems[i].description)),
              _cell(
                _money(proposal.lineItems[i].monthlyRate),
                align: pw.TextAlign.right,
              ),
              _cell(
                '${proposal.lineItems[i].months}',
                align: pw.TextAlign.right,
              ),
              _cell(
                '${proposal.lineItems[i].days}',
                align: pw.TextAlign.right,
              ),
              _cell(
                _money(proposal.lineItems[i].totalRate),
                align: pw.TextAlign.right,
              ),
            ],
          ),
      ],
    );
  }

  static pw.Widget _totals(Proposal proposal) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.SizedBox(
              width: 220,
              child: pw.Table(
                border:
                    pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.1),
                  1: pw.FlexColumnWidth(1.2),
                },
                children: [
                  pw.TableRow(
                    children: [
                      _cell('Sub Total', bold: true),
                      _cell(
                        _money(proposal.subtotal),
                        bold: true,
                        align: pw.TextAlign.right,
                      ),
                    ],
                  ),
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _cell('Total', bold: true),
                      _cell(
                        _money(proposal.subtotal),
                        bold: true,
                        align: pw.TextAlign.right,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Total In Words',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.left,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                _safe(proposal.totalInWords),
                style: const pw.TextStyle(fontSize: 9),
                textAlign: pw.TextAlign.left,
              ),
            ],
          ),
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
