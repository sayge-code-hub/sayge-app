import '../../../../core/config/app_invoice_config.dart';
import '../../../proposals/domain/entities/proposal.dart';

/// Maps a staffing proposal into invoice draft fields (no scheduling).
abstract final class ProposalToInvoiceMapper {
  /// Prefill payload for opening a new invoice from a proposal.
  static ProposalInvoiceDraft draftFrom(Proposal proposal, {DateTime? at}) {
    final now = at ?? DateTime.now();
    final lines = proposal.lineItems
        .where(
          (line) =>
              line.description.trim().isNotEmpty || line.totalRate > 0,
        )
        .map(
          (line) => ProposalInvoiceDraftLine(
            particulars: _particulars(line),
            amount: _formatAmount(line.totalRate),
          ),
        )
        .toList(growable: false);

    return ProposalInvoiceDraft(
      invoiceDate: now,
      placeOfSupply: normalizePlaceOfSupply(proposal.placeOfSupply),
      buyerName: proposal.billToName.trim(),
      buyerCompany: proposal.billToCompany.trim(),
      buyerAddress: proposal.billToAddress.trim(),
      buyerGstin: proposal.billToGstin.trim(),
      buyerContact: '',
      poNumber: '',
      intraState: inferIntraState(proposal.billToGstin),
      lines: lines.isEmpty
          ? const [ProposalInvoiceDraftLine(particulars: '', amount: '')]
          : lines,
      sourceProposalRef: proposal.referenceNo.trim(),
    );
  }

  /// Same state code on buyer + company GSTIN ⇒ intra-state (CGST+SGST).
  static bool inferIntraState(String buyerGstin) {
    final buyer = buyerGstin.trim().toUpperCase();
    final company = AppInvoiceConfig.companyGstin.trim().toUpperCase();
    if (buyer.length >= 2 && company.length >= 2) {
      return buyer.substring(0, 2) == company.substring(0, 2);
    }
    return AppInvoiceConfig.defaultIntraState;
  }

  /// Strip trailing "(27)" style codes from proposal place-of-supply.
  static String normalizePlaceOfSupply(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return AppInvoiceConfig.defaultPlaceOfSupply;
    final withoutCode = trimmed.replaceAll(RegExp(r'\s*\(\d{2}\)\s*$'), '');
    return withoutCode.trim().isEmpty
        ? AppInvoiceConfig.defaultPlaceOfSupply
        : withoutCode.trim();
  }

  static String _particulars(ProposalLineItem line) {
    final desc = line.description.trim();
    if (desc.isEmpty) return 'Services';
    if (line.months > 0) {
      final unit = line.months == 1 ? 'month' : 'months';
      return '$desc (${line.months} $unit)';
    }
    if (line.days > 0) {
      final unit = line.days == 1 ? 'day' : 'days';
      return '$desc (${line.days} $unit)';
    }
    return desc;
  }

  static String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) return '${amount.round()}';
    return amount.toStringAsFixed(2);
  }
}

class ProposalInvoiceDraftLine {
  const ProposalInvoiceDraftLine({
    required this.particulars,
    required this.amount,
  });

  final String particulars;
  final String amount;
}

class ProposalInvoiceDraft {
  const ProposalInvoiceDraft({
    required this.invoiceDate,
    required this.placeOfSupply,
    required this.buyerName,
    required this.buyerCompany,
    required this.buyerAddress,
    required this.buyerGstin,
    required this.buyerContact,
    required this.poNumber,
    required this.intraState,
    required this.lines,
    required this.sourceProposalRef,
  });

  final DateTime invoiceDate;
  final String placeOfSupply;
  final String buyerName;
  final String buyerCompany;
  final String buyerAddress;
  final String buyerGstin;
  final String buyerContact;
  final String poNumber;
  final bool intraState;
  final List<ProposalInvoiceDraftLine> lines;
  final String sourceProposalRef;
}
