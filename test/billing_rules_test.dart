import 'package:flutter_test/flutter_test.dart';
import 'package:sayge_app/core/billing/billing_models.dart';

void main() {
  group('BillingRules.deriveStatus', () {
    final periodEnd = DateTime(2026, 10, 31);

    test('settled period is active', () {
      expect(
        BillingRules.deriveStatus(
          paymentStatus: BillingPaymentStatus.paid,
          periodEnd: periodEnd,
          graceDays: 7,
          now: DateTime(2026, 11, 20),
        ),
        BillingStatus.active,
      );
      expect(
        BillingRules.deriveStatus(
          paymentStatus: BillingPaymentStatus.waived,
          periodEnd: periodEnd,
          graceDays: 7,
          now: DateTime(2026, 11, 20),
        ),
        BillingStatus.active,
      );
    });

    test('unpaid inside grace is past_due', () {
      // period_end + 1 day + 7 grace → Nov 8
      expect(
        BillingRules.deriveStatus(
          paymentStatus: BillingPaymentStatus.unpaid,
          periodEnd: periodEnd,
          graceDays: 7,
          now: DateTime(2026, 11, 5),
        ),
        BillingStatus.pastDue,
      );
    });

    test('unpaid after grace is read_only', () {
      expect(
        BillingRules.deriveStatus(
          paymentStatus: BillingPaymentStatus.unpaid,
          periodEnd: periodEnd,
          graceDays: 7,
          now: DateTime(2026, 11, 10),
        ),
        BillingStatus.readOnly,
      );
    });

    test('grace_days is configurable', () {
      expect(
        BillingRules.deriveStatus(
          paymentStatus: BillingPaymentStatus.unpaid,
          periodEnd: periodEnd,
          graceDays: 0,
          now: DateTime(2026, 11, 1, 12),
        ),
        BillingStatus.readOnly,
      );
    });
  });

  group('BillingRules.effectiveAmountDue', () {
    test('list price when no offer', () {
      expect(
        BillingRules.effectiveAmountDue(listPriceInr: 999),
        999,
      );
    });

    test('percent off', () {
      expect(
        BillingRules.effectiveAmountDue(
          listPriceInr: 1000,
          offerPercentOff: 50,
        ),
        500,
      );
    });

    test('fixed offer price', () {
      expect(
        BillingRules.effectiveAmountDue(
          listPriceInr: 999,
          offerFixedPrice: 1,
        ),
        1,
      );
    });

    test('expired offer falls back to list', () {
      expect(
        BillingRules.effectiveAmountDue(
          listPriceInr: 999,
          offerFixedPrice: 1,
          offerEndsAt: DateTime(2026, 1, 1),
          now: DateTime(2026, 10, 27),
        ),
        999,
      );
    });
  });

  group('BillingRules.canConsumeSeat', () {
    test('blocks at cap', () {
      expect(
        BillingRules.canConsumeSeat(
          activeEmployees: 5,
          employeeLimit: 5,
          writesAllowed: true,
        ),
        isFalse,
      );
    });

    test('allows under cap', () {
      expect(
        BillingRules.canConsumeSeat(
          activeEmployees: 4,
          employeeLimit: 5,
          writesAllowed: true,
        ),
        isTrue,
      );
    });

    test('blocks when read-only even under cap', () {
      expect(
        BillingRules.canConsumeSeat(
          activeEmployees: 1,
          employeeLimit: 30,
          writesAllowed: false,
        ),
        isFalse,
      );
    });
  });

  group('BillingRules messaging', () {
    test('growth uses contact us', () {
      expect(
        BillingRules.seatLimitMessage(planCode: 'growth', employeeLimit: 30),
        contains('Contact us'),
      );
    });

    test('starter suggests upgrade', () {
      expect(
        BillingRules.seatLimitMessage(planCode: 'starter', employeeLimit: 10),
        contains('Upgrade'),
      );
    });
  });

  group('plan catalog expectations', () {
    test('free starter growth limits', () {
      const free = BillingPlan(
        code: 'free',
        name: 'Free',
        priceInr: 0,
        employeeLimit: 5,
      );
      const starter = BillingPlan(
        code: 'starter',
        name: 'Starter',
        priceInr: 499,
        employeeLimit: 10,
      );
      const growth = BillingPlan(
        code: 'growth',
        name: 'Growth',
        priceInr: 999,
        employeeLimit: 30,
      );
      expect(free.employeeLimit, 5);
      expect(starter.priceInr, 499);
      expect(growth.employeeLimit, 30);
    });
  });
}
