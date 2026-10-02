import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_display_config.dart';
import '../../../../core/config/app_payroll_config.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/pdf_saver.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../hrms/domain/entities/employee.dart';
import '../../data/payslip_pdf_builder.dart';
import '../../domain/entities/payslip.dart';
import '../../domain/services/payslip_calculator.dart';

Future<void> showPayslipPreview({
  required BuildContext context,
  required Employee employee,
  required int month,
  required int year,
}) {
  final slip = PayslipCalculator.fromEmployee(
    employee: employee,
    month: month,
    year: year,
  );

  final isDesktop = Breakpoints.isDesktop(context);
  final size = MediaQuery.sizeOf(context);
  // Landscape-oriented dialog.
  final width = isDesktop ? 980.0 : size.width * 0.96;
  final height = isDesktop ? 620.0 : size.height * 0.82;

  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 48 : 16,
          vertical: 24,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        child: SizedBox(
          width: width,
          height: height,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            employee.employeeName,
                            style: Theme.of(dialogContext)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Payslip · ${slip.periodLabel}',
                            style: Theme.of(dialogContext)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontSize: 12,
                                  color: AppColors.textLight,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Download PDF',
                      onPressed: () async {
                        try {
                          await downloadPayslipPdf(
                            slips: [slip],
                            filename:
                                'Payslip_${employee.employeeId}_${slip.periodLabel}.pdf',
                          );
                        } catch (_) {
                          if (!dialogContext.mounted) return;
                          await showAppMessageDialog(
                            dialogContext,
                            title: 'Payroll',
                            message: 'Could not download payslip. Try again.',
                          );
                        }
                      },
                      icon: const Icon(Icons.download_outlined),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: ColoredBox(
                  color: AppColors.surface,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 920),
                        child: _PayslipPreviewCard(slip: slip),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> downloadPayslipPdf({
  required List<Payslip> slips,
  required String filename,
}) async {
  final doc = await PayslipPdfBuilder.build(slips);
  final bytes = await doc.save();
  await savePdfBytes(bytes: Uint8List.fromList(bytes), filename: filename);
}

class _PayslipPreviewCard extends StatelessWidget {
  const _PayslipPreviewCard({required this.slip});

  final Payslip slip;

  static final _amount = NumberFormat.decimalPattern(AppDisplayConfig.locale);
  static final _date = DateFormat(AppDisplayConfig.datePattern);

  String _money(num value) => _amount.format(value.round());

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/sayge_logo.webp',
                height: 32,
                semanticLabel: 'Sayge',
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Payslip for the month of ${slip.periodLabel}',
                      textAlign: TextAlign.right,
                      style: textTheme.titleMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppPayrollConfig.amountsNote,
                      textAlign: TextAlign.right,
                      style: textTheme.bodyMedium?.copyWith(
                        fontSize: 11,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _infoGrid(textTheme),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 520;
              final earnings = _amountBlock(
                textTheme,
                title: 'Earnings',
                lines: slip.earnings,
                totalLabel: 'Gross Earnings',
                total: slip.grossEarnings,
              );
              final deductions = _amountBlock(
                textTheme,
                title: 'Deductions',
                lines: slip.deductions,
                totalLabel: 'Total Deductions',
                total: slip.totalDeductions,
              );
              if (stacked) {
                return Column(
                  children: [
                    earnings,
                    const SizedBox(height: 12),
                    deductions,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: earnings),
                  const SizedBox(width: 12),
                  Expanded(child: deductions),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          _borderedRow(
            textTheme,
            left: 'Net In Hand/ Salary to Credit',
            right: _money(slip.netPay),
            emphasize: true,
          ),
          const SizedBox(height: 12),
          Text(
            'Net Pay : ${slip.netPayInWords}',
            style: textTheme.bodyMedium?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AppPayrollConfig.disclaimer,
            style: textTheme.bodyMedium?.copyWith(
              fontSize: 10,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoGrid(TextTheme textTheme) {
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
      ['Grade', slip.grade, 'PAN', slip.pan.isEmpty ? '-' : slip.pan],
      [
        'DOJ',
        _date.format(slip.dateOfJoining),
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

    return Table(
      border: TableBorder.all(color: AppColors.border, width: 1),
      columnWidths: const {
        0: FlexColumnWidth(1.3),
        1: FlexColumnWidth(1.7),
        2: FlexColumnWidth(1.3),
        3: FlexColumnWidth(1.7),
      },
      children: [
        for (final row in rows)
          TableRow(
            children: [
              for (var i = 0; i < 4; i++)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  child: Text(
                    row[i],
                    style: textTheme.bodyMedium?.copyWith(
                      fontSize: 11,
                      fontWeight: i.isEven && row[i].isNotEmpty
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _amountBlock(
    TextTheme textTheme, {
    required String title,
    required List<PayslipLine> lines,
    required String totalLabel,
    required double total,
  }) {
    return Table(
      border: TableBorder.all(color: AppColors.border, width: 1),
      columnWidths: const {
        0: FlexColumnWidth(2.2),
        1: FlexColumnWidth(1),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: AppColors.surfaceMuted),
          children: [
            _cell(textTheme, title, bold: true, center: true),
            _cell(textTheme, '', bold: true),
          ],
        ),
        TableRow(
          decoration: const BoxDecoration(color: AppColors.surface),
          children: [
            _cell(textTheme, 'Description', bold: true),
            _cell(textTheme, 'Amount', bold: true, right: true),
          ],
        ),
        for (final line in lines)
          TableRow(
            children: [
              _cell(textTheme, line.description),
              _cell(textTheme, _money(line.amount), right: true),
            ],
          ),
        TableRow(
          decoration: const BoxDecoration(color: AppColors.surface),
          children: [
            _cell(textTheme, totalLabel, bold: true),
            _cell(textTheme, _money(total), bold: true, right: true),
          ],
        ),
      ],
    );
  }

  Widget _borderedRow(
    TextTheme textTheme, {
    required String left,
    required String right,
    bool emphasize = false,
  }) {
    return Table(
      border: TableBorder.all(color: AppColors.border, width: 1),
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(1),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: AppColors.surfaceMuted),
          children: [
            _cell(textTheme, left, bold: emphasize),
            _cell(textTheme, right, bold: emphasize, right: true),
          ],
        ),
      ],
    );
  }

  Widget _cell(
    TextTheme textTheme,
    String text, {
    bool bold = false,
    bool right = false,
    bool center = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Text(
        text,
        textAlign: center
            ? TextAlign.center
            : right
                ? TextAlign.right
                : TextAlign.left,
        style: textTheme.bodyMedium?.copyWith(
          fontSize: 11,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}
