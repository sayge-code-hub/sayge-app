import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/config/app_display_config.dart';
import '../../../../core/config/app_payroll_config.dart';
import '../domain/entities/payslip.dart';

/// Builds salary-slip PDF pages matching the Sayge payslip template.
abstract final class PayslipPdfBuilder {
  static final _amount = NumberFormat.decimalPattern(AppDisplayConfig.locale);
  static final _date = DateFormat(AppDisplayConfig.datePattern);

  static const _logoAsset = 'assets/images/sayge_logo.png';

  static Future<pw.Document> build(List<Payslip> slips) async {
    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load(_logoAsset);
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {
      logoImage = null;
    }

    final doc = pw.Document();
    for (final slip in slips) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
          build: (_) => _PayslipPage(slip: slip, logo: logoImage),
        ),
      );
    }
    return doc;
  }

  static String money(num value) => _amount.format(value.round());
}

class _PayslipPage extends pw.StatelessWidget {
  _PayslipPage({required this.slip, this.logo});

  final Payslip slip;
  final pw.MemoryImage? logo;

  @override
  pw.Widget build(pw.Context context) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logo != null) pw.Image(logo!, height: 28),
            if (logo != null) pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Payslip for the month of ${slip.periodLabel}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    AppPayrollConfig.amountsNote,
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        _infoTable(),
        pw.SizedBox(height: 12),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _amountBlock(
                title: 'Earnings',
                lines: slip.earnings,
                totalLabel: 'Gross Earnings',
                total: slip.grossEarnings,
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: _amountBlock(
                title: 'Deductions',
                lines: slip.deductions,
                totalLabel: 'Total Deductions',
                total: slip.totalDeductions,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        _netRow(),
        pw.SizedBox(height: 8),
        pw.Text(
          'Net Pay : ${slip.netPayInWords}',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.Spacer(),
        pw.Text(
          AppPayrollConfig.disclaimer,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ],
    );
  }

  pw.Widget _infoTable() {
    final rows = <List<String>>[
      ['Employee Code', slip.employeeId, 'Location', slip.location],
      [
        'Employee Name',
        slip.employeeName,
        'IFSC Code',
        slip.ifsc.isEmpty ? '-' : slip.ifsc,
      ],
      [
        'Department',
        slip.department,
        'Bank A/c No.',
        slip.bankAccount.isEmpty ? '-' : slip.bankAccount,
      ],
      [
        'Grade',
        slip.grade,
        'PAN',
        slip.pan.isEmpty ? '-' : slip.pan,
      ],
      [
        'DOJ',
        PayslipPdfBuilder._date.format(slip.dateOfJoining),
        'UAN',
        slip.uan.isEmpty ? '-' : slip.uan,
      ],
      [
        'Designation',
        slip.designation,
        'Payable Days',
        '${slip.payableDays}',
      ],
      ['LOP Days', '${slip.lopDays}', '', ''],
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.3),
        1: pw.FlexColumnWidth(1.7),
        2: pw.FlexColumnWidth(1.3),
        3: pw.FlexColumnWidth(1.7),
      },
      children: [
        for (final row in rows)
          pw.TableRow(
            children: [
              for (var i = 0; i < 4; i++)
                _pad(
                  row[i],
                  bold: i.isEven && row[i].isNotEmpty,
                ),
            ],
          ),
      ],
    );
  }

  pw.Widget _amountBlock({
    required String title,
    required List<PayslipLine> lines,
    required String totalLabel,
    required double total,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.2),
        1: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _pad(title, bold: true, center: true),
            _pad('', bold: true),
          ],
        ),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _pad('Description', bold: true),
            _pad('Amount', bold: true, right: true),
          ],
        ),
        for (final line in lines)
          pw.TableRow(
            children: [
              _pad(line.description),
              _pad(PayslipPdfBuilder.money(line.amount), right: true),
            ],
          ),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _pad(totalLabel, bold: true),
            _pad(PayslipPdfBuilder.money(total), bold: true, right: true),
          ],
        ),
      ],
    );
  }

  pw.Widget _netRow() {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _pad('Net In Hand/ Salary to Credit', bold: true),
            _pad(
              PayslipPdfBuilder.money(slip.netPay),
              bold: true,
              right: true,
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _pad(
    String text, {
    bool bold = false,
    bool right = false,
    bool center = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        textAlign: center
            ? pw.TextAlign.center
            : right
                ? pw.TextAlign.right
                : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}
