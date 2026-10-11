import '../../domain/entities/expense.dart';

class ExpenseModel extends Expense {
  const ExpenseModel({
    required super.id,
    required super.madeFor,
    required super.amount,
    required super.paidFrom,
    required super.category,
    super.clientId,
    super.clientName,
    super.approvalStatus,
    super.expenseDate,
    super.receiptPath,
    super.receiptName,
    super.createdAt,
    super.createdBy,
    super.approvedBy,
    super.approvedAt,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    String? clientName;
    final nested = json['clients'];
    if (nested is Map) {
      clientName = nested['name']?.toString();
    }
    clientName ??= json['client_name']?.toString();

    final rawClientId = json['client_id']?.toString().trim();
    DateTime? parseOptionalDate(dynamic value) {
      if (value == null) return null;
      final raw = value.toString().trim();
      if (raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    return ExpenseModel(
      id: (json['id'] ?? '').toString(),
      madeFor: (json['made_for'] ?? '').toString(),
      amount: double.tryParse('${json['amount'] ?? 0}') ?? 0,
      paidFrom: (json['paid_from'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      clientId: (rawClientId == null || rawClientId.isEmpty) ? null : rawClientId,
      clientName: clientName,
      approvalStatus: ExpenseApprovalStatus.fromDb(
        json['approval_status']?.toString(),
      ),
      expenseDate: parseOptionalDate(json['expense_date']),
      receiptPath: json['receipt_path']?.toString(),
      receiptName: json['receipt_name']?.toString(),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
      createdBy: json['created_by']?.toString(),
      approvedBy: json['approved_by']?.toString(),
      approvedAt: DateTime.tryParse('${json['approved_at'] ?? ''}'),
    );
  }

  Map<String, dynamic> toJson() {
    String? ymd(DateTime? d) {
      if (d == null) return null;
      return '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
    }

    return {
      'id': id,
      'made_for': madeFor,
      'amount': amount,
      'paid_from': paidFrom,
      'category': category,
      'client_id': isCompanyExpense ? null : clientId,
      'expense_date': ymd(expenseDate ?? createdAt ?? DateTime.now()),
      if (receiptPath != null && receiptPath!.isNotEmpty)
        'receipt_path': receiptPath,
      if (receiptName != null && receiptName!.isNotEmpty)
        'receipt_name': receiptName,
      if (createdBy != null && createdBy!.isNotEmpty) 'created_by': createdBy,
    };
  }

  factory ExpenseModel.fromEntity(Expense expense) {
    return ExpenseModel(
      id: expense.id,
      madeFor: expense.madeFor,
      amount: expense.amount,
      paidFrom: expense.paidFrom,
      category: expense.category,
      clientId: expense.clientId,
      clientName: expense.clientName,
      approvalStatus: expense.approvalStatus,
      expenseDate: expense.expenseDate,
      receiptPath: expense.receiptPath,
      receiptName: expense.receiptName,
      createdAt: expense.createdAt,
      createdBy: expense.createdBy,
      approvedBy: expense.approvedBy,
      approvedAt: expense.approvedAt,
    );
  }
}
