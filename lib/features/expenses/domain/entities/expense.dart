class Expense {
  const Expense({
    required this.id,
    required this.madeFor,
    required this.amount,
    required this.paidFrom,
    required this.category,
    this.createdAt,
  });

  final String id;
  final String madeFor;
  final double amount;
  final String paidFrom;
  final String category;
  final DateTime? createdAt;

  static const categories = <String>[
    'Software Tools',
    'Commissions',
    'CA',
    'Accountant Consulting',
  ];
}
