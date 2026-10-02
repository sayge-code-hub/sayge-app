part of 'proposals_bloc.dart';

enum ProposalsStatus { initial, loading, ready, editing, saving, failure }

enum ProposalsView { list, form }

class DraftLine extends Equatable {
  const DraftLine({
    required this.description,
    required this.monthlyRate,
    required this.months,
    required this.days,
  });

  final String description;
  final String monthlyRate;
  final String months;
  final String days;

  DraftLine copyWith({
    String? description,
    String? monthlyRate,
    String? months,
    String? days,
  }) {
    return DraftLine(
      description: description ?? this.description,
      monthlyRate: monthlyRate ?? this.monthlyRate,
      months: months ?? this.months,
      days: days ?? this.days,
    );
  }

  @override
  List<Object?> get props => [description, monthlyRate, months, days];
}

class ProposalsState extends Equatable {
  const ProposalsState({
    required this.status,
    required this.view,
    required this.proposals,
    required this.draftLines,
    required this.referenceNo,
    required this.placeOfSupply,
    required this.vendorCode,
    required this.entityCode,
    required this.billToName,
    required this.billToCompany,
    required this.billToAddress,
    required this.billToGstin,
    required this.shipToName,
    required this.shipToCompany,
    required this.shipToAddress,
    required this.shipToGstin,
    required this.notes,
    this.editingId,
    this.quoteDate,
    this.expiryDate,
    this.errorMessage,
  });

  factory ProposalsState.initial() {
    return const ProposalsState(
      status: ProposalsStatus.initial,
      view: ProposalsView.list,
      proposals: [],
      draftLines: [],
      referenceNo: '',
      placeOfSupply: '',
      vendorCode: '',
      entityCode: '',
      billToName: '',
      billToCompany: '',
      billToAddress: '',
      billToGstin: '',
      shipToName: '',
      shipToCompany: '',
      shipToAddress: '',
      shipToGstin: '',
      notes: '',
    );
  }

  final ProposalsStatus status;
  final ProposalsView view;
  final List<Proposal> proposals;
  final List<DraftLine> draftLines;
  final String referenceNo;
  final DateTime? quoteDate;
  final DateTime? expiryDate;
  final String placeOfSupply;
  final String vendorCode;
  final String entityCode;
  final String billToName;
  final String billToCompany;
  final String billToAddress;
  final String billToGstin;
  final String shipToName;
  final String shipToCompany;
  final String shipToAddress;
  final String shipToGstin;
  final String notes;
  /// When set, Save updates this proposal instead of creating a new one.
  final String? editingId;
  final String? errorMessage;

  bool get isEditing => editingId != null;

  double get draftSubtotal {
    var sum = 0.0;
    for (final line in draftLines) {
      final rate = double.tryParse(line.monthlyRate.trim()) ?? 0;
      final months = int.tryParse(line.months.trim()) ?? 0;
      final days = int.tryParse(line.days.trim()) ?? 0;
      sum += ProposalCalculator.lineTotal(
        monthlyRate: rate,
        months: months,
        days: days,
      );
    }
    return sum;
  }

  String? validateForm() {
    if (referenceNo.trim().isEmpty) return 'Reference number is required';
    if (quoteDate == null) return 'Quote date is required';
    if (expiryDate == null) return 'Expiry date is required';
    if (billToCompany.trim().isEmpty && billToName.trim().isEmpty) {
      return 'Bill To name or company is required';
    }
    if (draftLines.isEmpty) return 'Add at least one line item';
    for (var i = 0; i < draftLines.length; i++) {
      final line = draftLines[i];
      if (line.description.trim().isEmpty) {
        return 'Line ${i + 1}: description is required';
      }
      if (double.tryParse(line.monthlyRate.trim()) == null) {
        return 'Line ${i + 1}: enter a valid monthly rate';
      }
      if (int.tryParse(line.months.trim()) == null) {
        return 'Line ${i + 1}: enter valid months';
      }
      if (int.tryParse(line.days.trim()) == null) {
        return 'Line ${i + 1}: enter valid days';
      }
    }
    return null;
  }

  ProposalsState copyWith({
    ProposalsStatus? status,
    ProposalsView? view,
    List<Proposal>? proposals,
    List<DraftLine>? draftLines,
    String? referenceNo,
    DateTime? quoteDate,
    DateTime? expiryDate,
    String? placeOfSupply,
    String? vendorCode,
    String? entityCode,
    String? billToName,
    String? billToCompany,
    String? billToAddress,
    String? billToGstin,
    String? shipToName,
    String? shipToCompany,
    String? shipToAddress,
    String? shipToGstin,
    String? notes,
    String? editingId,
    String? errorMessage,
    bool clearError = false,
    bool clearEditingId = false,
  }) {
    return ProposalsState(
      status: status ?? this.status,
      view: view ?? this.view,
      proposals: proposals ?? this.proposals,
      draftLines: draftLines ?? this.draftLines,
      referenceNo: referenceNo ?? this.referenceNo,
      quoteDate: quoteDate ?? this.quoteDate,
      expiryDate: expiryDate ?? this.expiryDate,
      placeOfSupply: placeOfSupply ?? this.placeOfSupply,
      vendorCode: vendorCode ?? this.vendorCode,
      entityCode: entityCode ?? this.entityCode,
      billToName: billToName ?? this.billToName,
      billToCompany: billToCompany ?? this.billToCompany,
      billToAddress: billToAddress ?? this.billToAddress,
      billToGstin: billToGstin ?? this.billToGstin,
      shipToName: shipToName ?? this.shipToName,
      shipToCompany: shipToCompany ?? this.shipToCompany,
      shipToAddress: shipToAddress ?? this.shipToAddress,
      shipToGstin: shipToGstin ?? this.shipToGstin,
      notes: notes ?? this.notes,
      editingId: clearEditingId ? null : (editingId ?? this.editingId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        view,
        proposals,
        draftLines,
        referenceNo,
        quoteDate,
        expiryDate,
        placeOfSupply,
        vendorCode,
        entityCode,
        billToName,
        billToCompany,
        billToAddress,
        billToGstin,
        shipToName,
        shipToCompany,
        shipToAddress,
        shipToGstin,
        notes,
        editingId,
        errorMessage,
      ];
}
