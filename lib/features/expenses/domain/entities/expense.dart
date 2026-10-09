enum ExpenseApprovalStatus {
  pending,
  approved,
  rejected;

  static ExpenseApprovalStatus fromDb(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'approved':
        return ExpenseApprovalStatus.approved;
      case 'rejected':
        return ExpenseApprovalStatus.rejected;
      case 'pending':
      default:
        return ExpenseApprovalStatus.pending;
    }
  }

  String get dbValue => name;

  String get label {
    switch (this) {
      case ExpenseApprovalStatus.pending:
        return 'Pending';
      case ExpenseApprovalStatus.approved:
        return 'Approved';
      case ExpenseApprovalStatus.rejected:
        return 'Rejected';
    }
  }
}

class Expense {
  const Expense({
    required this.id,
    required this.madeFor,
    required this.amount,
    required this.paidFrom,
    required this.category,
    this.clientId,
    this.clientName,
    this.approvalStatus = ExpenseApprovalStatus.pending,
    this.createdAt,
    this.createdBy,
    this.approvedBy,
    this.approvedAt,
  });

  /// Sentinel used in UI / profitability for company-wide expenses.
  static const companyScopeId = '__company__';
  static const companyScopeLabel = 'Company / Miscellaneous';

  final String id;
  final String madeFor;
  final double amount;
  final String paidFrom;
  final String category;

  /// Linked client id; `null` means company / miscellaneous.
  final String? clientId;
  final String? clientName;
  final ExpenseApprovalStatus approvalStatus;
  final DateTime? createdAt;
  final String? createdBy;
  final String? approvedBy;
  final DateTime? approvedAt;

  bool get isCompanyExpense =>
      clientId == null || clientId!.trim().isEmpty || clientId == companyScopeId;

  String get costCenterLabel {
    if (isCompanyExpense) return companyScopeLabel;
    final name = clientName?.trim() ?? '';
    return name.isEmpty ? 'Client' : name;
  }

  /// Company-level key for profitability (`companyScopeId` or normalized name).
  String get profitabilityCompanyKey {
    if (isCompanyExpense) return companyScopeId;
    final name = clientName?.trim() ?? '';
    if (name.isNotEmpty) return name.toLowerCase();
    return clientId!.trim();
  }

  /// Legacy id-based key (kept for older rows without a resolved name).
  String get profitabilityClientKey {
    if (isCompanyExpense) return companyScopeId;
    return clientId!.trim();
  }

  static const categories = <String>[
    'Software Tools',
    'Commissions',
    'CA',
    'Accountant Consulting',
    'Misc',
  ];
}
