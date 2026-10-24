import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_invoice_config.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/pdf/pdf_company_profile.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/document_email.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/pdf_saver.dart';
import '../../../../core/widgets/app_list_search_field.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../injection_container.dart';
import '../../../settings/domain/entities/settings_entities.dart';
import '../../../settings/domain/usecases/settings_usecases.dart';
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
                      AppListIconButton(
                        tooltip: 'Edit',
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          onEdit();
                        },
                        icon: Icons.edit_outlined,
                      ),
                    if (onClone != null)
                      AppListIconButton(
                        tooltip: 'Clone',
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          onClone();
                        },
                        icon: Icons.copy_outlined,
                      ),
                    AppListIconButton(
                      tooltip: 'Download PDF',
                      onPressed: () async {
                        try {
                          final company =
                              (await sl<GetCompanyDetailsUseCase>()())
                                  .fold((_) => null, (d) => d);
                          final doc = await InvoicePdfBuilder.build(
                            invoice,
                            company: company,
                          );
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
                      icon: Icons.download,
                    ),
                    AppListIconButton(
                      tooltip: 'Email PDF',
                      onPressed: () async {
                        await showEmailRecipientDialog(
                          context: dialogContext,
                          title: 'Email invoice',
                          onRecipient: (to) async {
                            final company =
                                (await sl<GetCompanyDetailsUseCase>()())
                                    .fold((_) => null, (d) => d);
                            final doc = await InvoicePdfBuilder.build(
                              invoice,
                              company: company,
                            );
                            final bytes =
                                Uint8List.fromList(await doc.save());
                            final name =
                                'Invoice_${invoice.invoiceNo.replaceAll(RegExp(r"[^\w.\-]+"), "_")}.pdf';
                            await emailPdfDocument(
                              bytes: bytes,
                              filename: name,
                              subject: 'Invoice ${invoice.invoiceNo}',
                              body:
                                  'Please find the invoice PDF attached (downloaded to your device).\n\nInvoice: ${invoice.invoiceNo}',
                              to: to,
                            );
                          },
                        );
                      },
                      icon: Icons.email_outlined,
                    ),
                    AppListIconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: Icons.close,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: ColoredBox(
                  color: AppColors.surface,
                  child: FutureBuilder<CompanyDetails?>(
                    future: sl<GetCompanyDetailsUseCase>()().then(
                      (r) => r.fold((_) => null, (d) => d),
                    ),
                    builder: (context, snapshot) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 760),
                            child: _InvoicePreviewCard(
                              invoice: invoice,
                              company: snapshot.data,
                            ),
                          ),
                        ),
                      );
                    },
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
  const _InvoicePreviewCard({
    required this.invoice,
    this.company,
  });

  final Invoice invoice;
  final CompanyDetails? company;

  static final _date = DateFormat('d-MMM-yy');

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final profile = PdfCompanyProfile.resolveSync(company);
    final buyer = invoice.buyerCompany.isNotEmpty
        ? invoice.buyerCompany
        : invoice.buyerName;
    final bankName = profile.bankName.trim().isEmpty ? '—' : profile.bankName;
    final bankAccount =
        profile.bankAccountNo.trim().isEmpty ? '—' : profile.bankAccountNo;
    final bankBranch =
        profile.bankBranch.trim().isEmpty ? '—' : profile.bankBranch;
    final bankIfsc = profile.bankIfsc.trim().isEmpty ? '—' : profile.bankIfsc;

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
                        profile.displayName,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(profile.address,
                          style: textTheme.bodyMedium?.copyWith(fontSize: 12)),
                      Text('GSTIN: ${profile.gstin}',
                          style: textTheme.bodyMedium?.copyWith(fontSize: 12)),
                      Text('PAN: ${profile.pan}',
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
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 520;
              final buyerBlock = Column(
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
              );
              final metaBlock = Column(
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
              );
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buyerBlock,
                    const SizedBox(height: 12),
                    metaBlock,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: buyerBlock),
                  Expanded(flex: 2, child: metaBlock),
                ],
              );
            },
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
          Text('Bank Name: $bankName',
              style: textTheme.bodyMedium?.copyWith(fontSize: 12)),
          Text('A/c No.: $bankAccount',
              style: textTheme.bodyMedium?.copyWith(fontSize: 12)),
          Text('Branch: $bankBranch',
              style: textTheme.bodyMedium?.copyWith(fontSize: 12)),
          Text('IFSC Code: $bankIfsc',
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
