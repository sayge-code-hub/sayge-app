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
    this.approvalStatus = ExpenseApprovalStatus.pending,
    this.createdAt,
    this.createdBy,
    this.approvedBy,
    this.approvedAt,
  });

  final String id;
  final String madeFor;
  final double amount;
  final String paidFrom;
  final String category;
  final ExpenseApprovalStatus approvalStatus;
  final DateTime? createdAt;
  final String? createdBy;
  final String? approvedBy;
  final DateTime? approvedAt;

  static const categories = <String>[
    'Software Tools',
    'Commissions',
    'CA',
    'Accountant Consulting',
    'Misc',
  ];
}
