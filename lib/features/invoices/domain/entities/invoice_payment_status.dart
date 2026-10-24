/// Invoice payment lifecycle.
enum InvoicePaymentStatus {
  unpaid,
  sent,
  partial,
  paid,
  overdue;

  static InvoicePaymentStatus fromDb(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'sent':
      case 'awaiting':
      case 'awaiting_payment':
        return InvoicePaymentStatus.sent;
      case 'partial':
        return InvoicePaymentStatus.partial;
      case 'paid':
        return InvoicePaymentStatus.paid;
      case 'overdue':
        return InvoicePaymentStatus.overdue;
      case 'unpaid':
      default:
        return InvoicePaymentStatus.unpaid;
    }
  }

  String get dbValue => name;

  String get label {
    switch (this) {
      case InvoicePaymentStatus.unpaid:
        return 'Unpaid';
      case InvoicePaymentStatus.sent:
        return 'Awaiting payment';
      case InvoicePaymentStatus.partial:
        return 'Partial';
      case InvoicePaymentStatus.paid:
        return 'Paid';
      case InvoicePaymentStatus.overdue:
        return 'Overdue';
    }
  }

  /// Effective status for display: overdue when unpaid/partial past [dueDate].
  static InvoicePaymentStatus effective({
    required InvoicePaymentStatus stored,
    required DateTime? dueDate,
    DateTime? today,
  }) {
    if (stored == InvoicePaymentStatus.paid) {
      return InvoicePaymentStatus.paid;
    }
    if (isOverdue(stored: stored, dueDate: dueDate, today: today)) {
      return InvoicePaymentStatus.overdue;
    }
    return stored == InvoicePaymentStatus.overdue
        ? InvoicePaymentStatus.unpaid
        : stored;
  }

  /// True when status is still open and due before today.
  static bool isOverdue({
    required InvoicePaymentStatus stored,
    required DateTime? dueDate,
    DateTime? today,
  }) {
    if (stored == InvoicePaymentStatus.paid) return false;
    if (dueDate == null) return false;
    final now = today ?? DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final open =
        stored == InvoicePaymentStatus.unpaid ||
        stored == InvoicePaymentStatus.sent ||
        stored == InvoicePaymentStatus.partial ||
        stored == InvoicePaymentStatus.overdue;
    return open && due.isBefore(todayDate);
  }
}
