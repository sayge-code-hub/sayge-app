import '../../domain/entities/expense.dart';

class ExpenseModel extends Expense {
  const ExpenseModel({
    required super.id,
    required super.madeFor,
    required super.amount,
    required super.paidFrom,
    required super.category,
    super.createdAt,
    super.createdBy,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: (json['id'] ?? '').toString(),
      madeFor: (json['made_for'] ?? '').toString(),
      amount: double.tryParse('${json['amount'] ?? 0}') ?? 0,
      paidFrom: (json['paid_from'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
      createdBy: json['created_by']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'made_for': madeFor,
      'amount': amount,
      'paid_from': paidFrom,
      'category': category,
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
      createdAt: expense.createdAt,
      createdBy: expense.createdBy,
    );
  }
}
