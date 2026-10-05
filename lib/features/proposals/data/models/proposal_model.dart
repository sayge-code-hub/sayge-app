import '../../domain/entities/proposal.dart';
import '../../domain/services/proposal_calculator.dart';

class ProposalLineItemModel extends ProposalLineItem {
  const ProposalLineItemModel({
    required super.id,
    required super.description,
    required super.monthlyRate,
    required super.months,
    required super.days,
    required super.totalRate,
    super.sortOrder,
  });

  factory ProposalLineItemModel.fromJson(Map<String, dynamic> json) {
    num readNum(String key) {
      final v = json[key];
      if (v is num) return v;
      return num.tryParse(v?.toString() ?? '') ?? 0;
    }

    return ProposalLineItemModel(
      id: (json['id'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      monthlyRate: readNum('monthly_rate').toDouble(),
      months: readNum('months').toInt(),
      days: readNum('days').toInt(),
      totalRate: readNum('total_rate').toDouble(),
      sortOrder: readNum('sort_order').toInt(),
    );
  }

  Map<String, dynamic> toJson({required String proposalId}) {
    return {
      'id': id,
      'proposal_id': proposalId,
      'description': description,
      'monthly_rate': monthlyRate,
      'months': months,
      'days': days,
      'total_rate': totalRate,
      'sort_order': sortOrder,
    };
  }
}

class ProposalModel extends Proposal {
  const ProposalModel({
    required super.id,
    required super.referenceNo,
    required super.quoteDate,
    required super.expiryDate,
    required super.placeOfSupply,
    required super.vendorCode,
    required super.entityCode,
    required super.billToName,
    required super.billToCompany,
    required super.billToAddress,
    required super.billToGstin,
    required super.shipToName,
    required super.shipToCompany,
    required super.shipToAddress,
    required super.shipToGstin,
    required super.notes,
    required super.lineItems,
    required super.subtotal,
    required super.totalInWords,
    super.poStatus,
  });

  factory ProposalModel.fromEntity(Proposal proposal) {
    return ProposalModel(
      id: proposal.id,
      referenceNo: proposal.referenceNo,
      quoteDate: proposal.quoteDate,
      expiryDate: proposal.expiryDate,
      placeOfSupply: proposal.placeOfSupply,
      vendorCode: proposal.vendorCode,
      entityCode: proposal.entityCode,
      billToName: proposal.billToName,
      billToCompany: proposal.billToCompany,
      billToAddress: proposal.billToAddress,
      billToGstin: proposal.billToGstin,
      shipToName: proposal.shipToName,
      shipToCompany: proposal.shipToCompany,
      shipToAddress: proposal.shipToAddress,
      shipToGstin: proposal.shipToGstin,
      notes: proposal.notes,
      lineItems: proposal.lineItems,
      subtotal: proposal.subtotal,
      totalInWords: proposal.totalInWords,
      poStatus: proposal.poStatus,
    );
  }

  factory ProposalModel.fromJson(Map<String, dynamic> json) {
    DateTime readDate(String key) {
      final raw = json[key];
      if (raw is DateTime) return raw;
      return DateTime.parse(raw.toString());
    }

    String readString(String key) => (json[key] ?? '').toString();

    num readNum(String key) {
      final v = json[key];
      if (v is num) return v;
      return num.tryParse(v?.toString() ?? '') ?? 0;
    }

    final linesRaw = json['proposal_line_items'];
    final lines = <ProposalLineItem>[];
    if (linesRaw is List) {
      for (final row in linesRaw) {
        if (row is Map<String, dynamic>) {
          lines.add(ProposalLineItemModel.fromJson(row));
        }
      }
      lines.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    final subtotal = readNum('subtotal').toDouble();

    return ProposalModel(
      id: readString('id'),
      referenceNo: readString('reference_no'),
      quoteDate: readDate('quote_date'),
      expiryDate: readDate('expiry_date'),
      placeOfSupply: readString('place_of_supply'),
      vendorCode: readString('vendor_code'),
      entityCode: readString('entity_code'),
      billToName: readString('bill_to_name'),
      billToCompany: readString('bill_to_company'),
      billToAddress: readString('bill_to_address'),
      billToGstin: readString('bill_to_gstin'),
      shipToName: readString('ship_to_name'),
      shipToCompany: readString('ship_to_company'),
      shipToAddress: readString('ship_to_address'),
      shipToGstin: readString('ship_to_gstin'),
      notes: readString('notes'),
      lineItems: lines,
      subtotal: subtotal,
      totalInWords: ProposalCalculator.amountInWords(subtotal),
      poStatus: ProposalPoStatus.fromStorage(readString('status')),
    );
  }

  Map<String, dynamic> toHeaderJson() {
    return {
      'id': id,
      'reference_no': referenceNo,
      'quote_date': quoteDate.toIso8601String().split('T').first,
      'expiry_date': expiryDate.toIso8601String().split('T').first,
      'place_of_supply': placeOfSupply,
      'vendor_code': vendorCode,
      'entity_code': entityCode,
      'bill_to_name': billToName,
      'bill_to_company': billToCompany,
      'bill_to_address': billToAddress,
      'bill_to_gstin': billToGstin,
      'ship_to_name': shipToName,
      'ship_to_company': shipToCompany,
      'ship_to_address': shipToAddress,
      'ship_to_gstin': shipToGstin,
      'notes': notes,
      'subtotal': subtotal,
      'status': poStatus.storageValue,
    };
  }
}
