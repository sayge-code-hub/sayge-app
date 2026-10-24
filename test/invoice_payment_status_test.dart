import 'package:flutter_test/flutter_test.dart';
import 'package:sayge_app/features/invoices/domain/entities/invoice_payment_status.dart';

void main() {
  group('InvoicePaymentStatus aging', () {
    final today = DateTime(2026, 10, 11);

    test('unpaid before due is not overdue', () {
      expect(
        InvoicePaymentStatus.isOverdue(
          stored: InvoicePaymentStatus.unpaid,
          dueDate: DateTime(2026, 10, 15),
          today: today,
        ),
        isFalse,
      );
      expect(
        InvoicePaymentStatus.effective(
          stored: InvoicePaymentStatus.unpaid,
          dueDate: DateTime(2026, 10, 15),
          today: today,
        ),
        InvoicePaymentStatus.unpaid,
      );
    });

    test('unpaid past due becomes overdue', () {
      expect(
        InvoicePaymentStatus.isOverdue(
          stored: InvoicePaymentStatus.unpaid,
          dueDate: DateTime(2026, 10, 1),
          today: today,
        ),
        isTrue,
      );
      expect(
        InvoicePaymentStatus.effective(
          stored: InvoicePaymentStatus.unpaid,
          dueDate: DateTime(2026, 10, 1),
          today: today,
        ),
        InvoicePaymentStatus.overdue,
      );
    });

    test('sent before due stays awaiting payment', () {
      expect(
        InvoicePaymentStatus.effective(
          stored: InvoicePaymentStatus.sent,
          dueDate: DateTime(2026, 10, 20),
          today: today,
        ),
        InvoicePaymentStatus.sent,
      );
      expect(InvoicePaymentStatus.sent.label, 'Awaiting payment');
    });

    test('sent past due becomes overdue', () {
      expect(
        InvoicePaymentStatus.isOverdue(
          stored: InvoicePaymentStatus.sent,
          dueDate: DateTime(2026, 10, 1),
          today: today,
        ),
        isTrue,
      );
      expect(
        InvoicePaymentStatus.effective(
          stored: InvoicePaymentStatus.sent,
          dueDate: DateTime(2026, 10, 1),
          today: today,
        ),
        InvoicePaymentStatus.overdue,
      );
    });

    test('partial past due becomes overdue', () {
      expect(
        InvoicePaymentStatus.effective(
          stored: InvoicePaymentStatus.partial,
          dueDate: DateTime(2026, 9, 30),
          today: today,
        ),
        InvoicePaymentStatus.overdue,
      );
    });

    test('paid never ages to overdue', () {
      expect(
        InvoicePaymentStatus.isOverdue(
          stored: InvoicePaymentStatus.paid,
          dueDate: DateTime(2026, 1, 1),
          today: today,
        ),
        isFalse,
      );
      expect(
        InvoicePaymentStatus.effective(
          stored: InvoicePaymentStatus.paid,
          dueDate: DateTime(2026, 1, 1),
          today: today,
        ),
        InvoicePaymentStatus.paid,
      );
    });

    test('missing due date is not overdue', () {
      expect(
        InvoicePaymentStatus.isOverdue(
          stored: InvoicePaymentStatus.unpaid,
          dueDate: null,
          today: today,
        ),
        isFalse,
      );
    });

    test('fromDb defaults unknown to unpaid', () {
      expect(InvoicePaymentStatus.fromDb(null), InvoicePaymentStatus.unpaid);
      expect(InvoicePaymentStatus.fromDb(''), InvoicePaymentStatus.unpaid);
      expect(InvoicePaymentStatus.fromDb('paid'), InvoicePaymentStatus.paid);
      expect(InvoicePaymentStatus.fromDb('sent'), InvoicePaymentStatus.sent);
      expect(
        InvoicePaymentStatus.fromDb('awaiting_payment'),
        InvoicePaymentStatus.sent,
      );
    });
  });
}
