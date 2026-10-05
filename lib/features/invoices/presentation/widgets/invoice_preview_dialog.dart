import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_invoice_config.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/pdf_saver.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../settings/presentation/widgets/client_name_label.dart';
import '../../data/invoice_pdf_builder.dart';
import '../../domain/entities/invoice.dart';

Future<void> showInvoicePreview({
  required BuildContext context,
  required Invoice invoice,
  VoidCallback? onEdit,
  VoidCallback? onClone,
}) {
  final isDesktop = Breakpoints.isDesktop(context);
  final size = MediaQuery.sizeOf(context);

  return showDialog<void>(
    context: context,
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
          width: isDesktop ? 860.0 : size.width * 0.96,
          height: isDesktop ? 740.0 : size.height * 0.88,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppInvoiceConfig.documentTitle,
                        style: Theme.of(dialogContext)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (onEdit != null)
                      IconButton(
                        tooltip: 'Edit',
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          onEdit();
                        },
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    if (onClone != null)
                      IconButton(
                        tooltip: 'Clone',
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          onClone();
                        },
                        icon: const Icon(Icons.copy_outlined),
                      ),
                    IconButton(
                      tooltip: 'Download PDF',
                      onPressed: () async {
                        try {
                          final doc = await InvoicePdfBuilder.build(invoice);
                          final bytes = await doc.save();
                          final name =
                              'Invoice_${invoice.invoiceNo.replaceAll(RegExp(r"[^\w.\-]+"), "_")}.pdf';
                          await savePdfBytes(
                            bytes: Uint8List.fromList(bytes),
                            filename: name,
                          );
                        } catch (_) {
                          if (!dialogContext.mounted) return;
                          await showAppMessageDialog(
                            dialogContext,
                            title: 'Invoices',
                            message: 'Could not download invoice.',
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
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: _InvoicePreviewCard(invoice: invoice),
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

class _InvoicePreviewCard extends StatelessWidget {
  const _InvoicePreviewCard({required this.invoice});

  final Invoice invoice;

  static final _date = DateFormat('d-MMM-yy');

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final buyer = invoice.buyerCompany.isNotEmpty
        ? invoice.buyerCompany
        : invoice.buyerName;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppInvoiceConfig.documentTitle,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppInvoiceConfig.companyName,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(AppInvoiceConfig.companyAddress,
                          style: textTheme.bodyMedium?.copyWith(fontSize: 12)),
                      Text('GSTIN: ${AppInvoiceConfig.companyGstin}',
                          style: textTheme.bodyMedium?.copyWith(fontSize: 12)),
                      Text('PAN: ${AppInvoiceConfig.companyPan}',
                          style: textTheme.bodyMedium?.copyWith(fontSize: 12)),
                    ],
                  ),
                ),
                Image.asset(
                  AppInvoiceConfig.logoAsset,
                  height: 32,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 3, color: const Color(0xFF1E3A5F)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Buyer: ',
                          style: textTheme.bodyMedium?.copyWith(fontSize: 12),
                        ),
                        Expanded(
                          child: buyer.isNotEmpty
                              ? ClientNameLabel(
                                  name: buyer,
                                  contactName: invoice.buyerName,
                                  style: textTheme.bodyMedium
                                      ?.copyWith(fontSize: 12),
                                  logoRadius: 7,
                                )
                              : Text(
                                  '—',
                                  style: textTheme.bodyMedium
                                      ?.copyWith(fontSize: 12),
                                ),
                        ),
                      ],
                    ),
                    if (invoice.buyerAddress.isNotEmpty)
                      Text(invoice.buyerAddress,
                          style: textTheme.bodyMedium?.copyWith(fontSize: 12)),
                    Text('Place of Supply: ${invoice.placeOfSupply}',
                        style: textTheme.bodyMedium?.copyWith(fontSize: 12)),
                    Text('GSTIN: ${invoice.buyerGstin}',
                        style: textTheme.bodyMedium?.copyWith(fontSize: 12)),
                    Text('Contact: ${invoice.buyerContact}',
                        style: textTheme.bodyMedium?.copyWith(fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invoice No.: ${invoice.invoiceNo}',
                        style: textTheme.bodyMedium?.copyWith(fontSize: 12)),
                    Text('Date: ${_date.format(invoice.invoiceDate)}',
                        style: textTheme.bodyMedium?.copyWith(fontSize: 12)),
                    Text(
                      'P.O.Number: ${invoice.poNumber.isEmpty ? '-' : invoice.poNumber}',
                      style: textTheme.bodyMedium?.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < invoice.lineItems.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Text('${i + 1}',
                        style: textTheme.bodyMedium?.copyWith(fontSize: 12)),
                  ),
                  Expanded(
                    child: Text(
                      invoice.lineItems[i].particulars,
                      style: textTheme.bodyMedium?.copyWith(fontSize: 12),
                    ),
                  ),
                  Text(
                    MoneyFormat.format(invoice.lineItems[i].amount),
                    style: textTheme.bodyMedium?.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
          const Divider(color: AppColors.border),
          Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('CGST  ${MoneyFormat.format(invoice.cgstAmount)}'),
                Text('SGST  ${MoneyFormat.format(invoice.sgstAmount)}'),
                Text('IGST  ${MoneyFormat.format(invoice.igstAmount)}'),
                Text(
                  'Total  ${MoneyFormat.format(invoice.totalAmount)}',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(invoice.amountInWords,
              style: textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 12),
          Text(
            'Declaration',
            style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            AppInvoiceConfig.declaration,
            style: textTheme.bodyMedium?.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            AppInvoiceConfig.gratitudeLine,
            style: textTheme.bodyMedium?.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 12),
          Text(
            "Company's Bank Details",
            style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text('Bank Name: ${AppInvoiceConfig.bankName}',
              style: textTheme.bodyMedium?.copyWith(fontSize: 12)),
          Text('A/c No.: ${AppInvoiceConfig.bankAccountNo}',
              style: textTheme.bodyMedium?.copyWith(fontSize: 12)),
          Text('Branch: ${AppInvoiceConfig.bankBranch}',
              style: textTheme.bodyMedium?.copyWith(fontSize: 12)),
          Text('IFSC Code: ${AppInvoiceConfig.bankIfsc}',
              style: textTheme.bodyMedium?.copyWith(fontSize: 12)),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: Column(
              children: [
                Image.asset(
                  AppInvoiceConfig.signatureAsset,
                  height: 60,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  isAntiAlias: true,
                  errorBuilder: (_, _, _) => const SizedBox(height: 64),
                ),
                Text(
                  AppInvoiceConfig.authorisedSignatoryLabel,
                  style: textTheme.labelLarge?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
