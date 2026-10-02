import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_proposal_config.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/pdf_saver.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../data/proposal_pdf_builder.dart';
import '../../domain/entities/proposal.dart';

Future<void> showProposalPreview({
  required BuildContext context,
  required Proposal proposal,
  VoidCallback? onEdit,
  VoidCallback? onClone,
}) {
  final isDesktop = Breakpoints.isDesktop(context);
  final size = MediaQuery.sizeOf(context);
  final width = isDesktop ? 820.0 : size.width * 0.96;
  final height = isDesktop ? 720.0 : size.height * 0.88;

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
                            AppProposalConfig.documentTitle,
                            style: Theme.of(dialogContext)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            proposal.referenceNo.isEmpty
                                ? 'Draft preview'
                                : proposal.referenceNo,
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
                          await downloadProposalPdf(proposal);
                        } catch (_) {
                          if (!dialogContext.mounted) return;
                          await showAppMessageDialog(
                            dialogContext,
                            title: 'Proposals',
                            message: 'Could not download proposal. Try again.',
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
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: _ProposalPreviewCard(proposal: proposal),
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

Future<void> downloadProposalPdf(Proposal proposal) async {
  final doc = await ProposalPdfBuilder.build(proposal);
  final bytes = await doc.save();
  final name =
      'Proposal_${proposal.referenceNo.replaceAll(RegExp(r'[^\w.\-]+'), '_')}.pdf';
  await savePdfBytes(bytes: Uint8List.fromList(bytes), filename: name);
}

class _ProposalPreviewCard extends StatelessWidget {
  const _ProposalPreviewCard({required this.proposal});

  final Proposal proposal;

  static final _date = DateFormat('MM/dd/yyyy');

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                'assets/images/sayge_logo.png',
                height: 28,
                errorBuilder: (_, _, _) => Text(
                  AppProposalConfig.companyName,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppProposalConfig.companyRegion,
                    style: textTheme.bodyMedium?.copyWith(fontSize: 12),
                    textAlign: TextAlign.right,
                  ),
                  Text(
                    AppProposalConfig.companyCountry,
                    style: textTheme.bodyMedium?.copyWith(fontSize: 12),
                    textAlign: TextAlign.right,
                  ),
                  Text(
                    'GSTIN: ${AppProposalConfig.companyGstin}',
                    style: textTheme.bodyMedium?.copyWith(fontSize: 12),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            AppProposalConfig.documentTitle,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _metaGrid(context),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _partyBlock(
                  context,
                  title: 'Bill To',
                  name: proposal.billToName,
                  company: proposal.billToCompany,
                  address: proposal.billToAddress,
                  gstin: proposal.billToGstin,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _partyBlock(
                  context,
                  title: 'Ship To',
                  name: proposal.shipToName,
                  company: proposal.shipToCompany,
                  address: proposal.shipToAddress,
                  gstin: proposal.shipToGstin,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _linesTable(context),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Sub Total  ${MoneyFormat.format(proposal.subtotal)}',
                  style: textTheme.titleMedium?.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total  ${MoneyFormat.format(proposal.subtotal)}',
                  style: textTheme.titleMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  proposal.totalInWords,
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppProposalConfig.notesHeading,
                      style: textTheme.labelLarge?.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      proposal.notes.isEmpty ? '-' : proposal.notes,
                      style: textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppProposalConfig.authorisedSignatureLabel,
                    style: textTheme.labelLarge?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 8),
                  Image.asset(
                    AppProposalConfig.signatureAsset,
                    height: 60,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    isAntiAlias: true,
                    errorBuilder: (_, _, _) => const SizedBox(height: 60),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaGrid(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12);
    final labelStyle = style?.copyWith(color: AppColors.textLight);

    Widget cell(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label, style: labelStyle),
            ),
            Expanded(child: Text(value.isEmpty ? '—' : value, style: style)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cell('Reference No', proposal.referenceNo)),
            Expanded(child: cell('Place of Supply', proposal.placeOfSupply)),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cell('Quote Date', _date.format(proposal.quoteDate))),
            Expanded(child: cell('Vendor Code', proposal.vendorCode)),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cell('Expiry Date', _date.format(proposal.expiryDate))),
            Expanded(child: cell('Entity Code', proposal.entityCode)),
          ],
        ),
      ],
    );
  }

  Widget _partyBlock(
    BuildContext context, {
    required String title,
    required String name,
    required String company,
    required String address,
    required String gstin,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.labelLarge?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.highlight,
          ),
        ),
        const SizedBox(height: 6),
        if (name.isNotEmpty)
          Text(name, style: textTheme.bodyMedium?.copyWith(fontSize: 12)),
        if (company.isNotEmpty)
          Text(company, style: textTheme.bodyMedium?.copyWith(fontSize: 12)),
        if (address.isNotEmpty)
          Text(
            address,
            style: textTheme.bodyMedium?.copyWith(fontSize: 12, height: 1.3),
          ),
        if (gstin.isNotEmpty)
          Text(
            'GSTIN $gstin',
            style: textTheme.bodyMedium?.copyWith(fontSize: 12),
          ),
      ],
    );
  }

  Widget _linesTable(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 11,
          color: AppColors.textLight,
        );
    final cellStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 12,
        );

    Widget headerCell(String text, {int flex = 1, TextAlign align = TextAlign.left}) {
      return Expanded(
        flex: flex,
        child: Text(text, style: headerStyle, textAlign: align),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.border),
            ),
          ),
          child: Row(
            children: [
              headerCell('#', flex: 1),
              headerCell('Item & Description', flex: 5),
              headerCell('Monthly', flex: 2, align: TextAlign.right),
              headerCell('Months', flex: 2, align: TextAlign.right),
              headerCell('Days', flex: 2, align: TextAlign.right),
              headerCell('Total', flex: 2, align: TextAlign.right),
            ],
          ),
        ),
        if (proposal.lineItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No line items',
              style: cellStyle?.copyWith(color: AppColors.textLight),
            ),
          )
        else
          for (var i = 0; i < proposal.lineItems.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: Text('${i + 1}', style: cellStyle),
                  ),
                  Expanded(
                    flex: 5,
                    child: Text(
                      proposal.lineItems[i].description,
                      style: cellStyle,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      MoneyFormat.format(proposal.lineItems[i].monthlyRate),
                      style: cellStyle,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${proposal.lineItems[i].months}',
                      style: cellStyle,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${proposal.lineItems[i].days}',
                      style: cellStyle,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      MoneyFormat.format(proposal.lineItems[i].totalRate),
                      style: cellStyle,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
