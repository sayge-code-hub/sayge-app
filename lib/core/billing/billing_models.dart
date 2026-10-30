// Per-company Saasify subscription models (Sayge = first client company_sayge).

enum BillingStatus {
  trialing,
  active,
  pastDue,
  readOnly;

  static BillingStatus fromDb(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'trialing':
        return BillingStatus.trialing;
      case 'past_due':
        return BillingStatus.pastDue;
      case 'read_only':
        return BillingStatus.readOnly;
      default:
        return BillingStatus.active;
    }
  }

  String get dbValue => switch (this) {
        BillingStatus.trialing => 'trialing',
        BillingStatus.active => 'active',
        BillingStatus.pastDue => 'past_due',
        BillingStatus.readOnly => 'read_only',
      };

  String get label => switch (this) {
        BillingStatus.trialing => 'Trialing',
        BillingStatus.active => 'Active',
        BillingStatus.pastDue => 'Past due',
        BillingStatus.readOnly => 'Read-only',
      };
}

enum BillingPaymentStatus {
  unpaid,
  paid,
  waived,
  comped;

  static BillingPaymentStatus fromDb(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'paid':
        return BillingPaymentStatus.paid;
      case 'waived':
        return BillingPaymentStatus.waived;
      case 'comped':
        return BillingPaymentStatus.comped;
      default:
        return BillingPaymentStatus.unpaid;
    }
  }

  String get dbValue => name;

  String get label => switch (this) {
        BillingPaymentStatus.unpaid => 'Unpaid',
        BillingPaymentStatus.paid => 'Paid',
        BillingPaymentStatus.waived => 'Waived',
        BillingPaymentStatus.comped => 'Comped',
      };

  bool get isSettled =>
      this == BillingPaymentStatus.paid ||
      this == BillingPaymentStatus.waived ||
      this == BillingPaymentStatus.comped;
}

class BillingPlan {
  const BillingPlan({
    required this.code,
    required this.name,
    required this.priceInr,
    required this.employeeLimit,
    this.sortOrder = 0,
  });

  final String code;
  final String name;
  final double priceInr;
  final int employeeLimit;
  final int sortOrder;

  factory BillingPlan.fromJson(Map<String, dynamic> json) {
    return BillingPlan(
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      priceInr: _num(json['price_inr']),
      employeeLimit: _int(json['employee_limit'], 5),
      sortOrder: _int(json['sort_order']),
    );
  }
}

class BillingPeriod {
  const BillingPeriod({
    required this.id,
    required this.periodYm,
    required this.planCode,
    required this.listPriceInr,
    required this.amountDueInr,
    required this.amountPaidInr,
    required this.paymentStatus,
    this.periodStart,
    this.periodEnd,
    this.paidAt,
    this.note = '',
    this.offerId,
  });

  final String id;
  final String periodYm;
  final String planCode;
  final double listPriceInr;
  final double amountDueInr;
  final double amountPaidInr;
  final BillingPaymentStatus paymentStatus;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final DateTime? paidAt;
  final String note;
  final String? offerId;

  factory BillingPeriod.fromJson(Map<String, dynamic> json) {
    return BillingPeriod(
      id: (json['id'] ?? '').toString(),
      periodYm: (json['period_ym'] ?? '').toString(),
      planCode: (json['plan_code'] ?? '').toString(),
      listPriceInr: _num(json['list_price_inr']),
      amountDueInr: _num(json['amount_due_inr']),
      amountPaidInr: _num(json['amount_paid_inr']),
      paymentStatus: BillingPaymentStatus.fromDb(
        json['payment_status']?.toString(),
      ),
      periodStart: _date(json['period_start']),
      periodEnd: _date(json['period_end']),
      paidAt: _date(json['paid_at']),
      note: (json['note'] ?? '').toString(),
      offerId: json['offer_id']?.toString(),
    );
  }
}

class BillingOffer {
  const BillingOffer({
    required this.id,
    required this.code,
    this.name = '',
    this.appliesToPlan,
    this.percentOff,
    this.fixedPriceInr,
    this.startsAt,
    this.endsAt,
    this.isActive = true,
  });

  final String id;
  final String code;
  final String name;
  final String? appliesToPlan;
  final double? percentOff;
  final double? fixedPriceInr;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool isActive;

  factory BillingOffer.fromJson(Map<String, dynamic> json) {
    return BillingOffer(
      id: (json['id'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      appliesToPlan: json['applies_to_plan']?.toString(),
      percentOff: json['percent_off'] == null ? null : _num(json['percent_off']),
      fixedPriceInr: json['fixed_price_inr'] == null
          ? null
          : _num(json['fixed_price_inr']),
      startsAt: _date(json['starts_at']),
      endsAt: _date(json['ends_at']),
      isActive: json['is_active'] != false,
    );
  }
}

/// Lightweight snapshot for gates/banners (any authenticated user).
class BillingSnapshot {
  const BillingSnapshot({
    required this.status,
    required this.writesAllowed,
    required this.posEnabled,
    required this.canAddEmployee,
    required this.activeEmployees,
    required this.employeeLimit,
    required this.planCode,
    required this.planName,
    this.graceDays = 7,
    this.currentPeriodEnd,
  });

  final BillingStatus status;
  final bool writesAllowed;
  final bool posEnabled;
  final bool canAddEmployee;
  final int activeEmployees;
  final int employeeLimit;
  final String planCode;
  final String planName;
  final int graceDays;
  final DateTime? currentPeriodEnd;

  static const permissive = BillingSnapshot(
    status: BillingStatus.active,
    writesAllowed: true,
    posEnabled: true,
    canAddEmployee: true,
    activeEmployees: 0,
    employeeLimit: 30,
    planCode: 'growth',
    planName: 'Growth',
  );

  bool get isPastDue => status == BillingStatus.pastDue;
  bool get isReadOnly => status == BillingStatus.readOnly;
  bool get atSeatCap => activeEmployees >= employeeLimit;
  bool get nearSeatCap =>
      employeeLimit > 0 && activeEmployees / employeeLimit >= 0.8;

  bool get isTopPlan => planCode == 'growth';

  factory BillingSnapshot.fromJson(Map<String, dynamic> json) {
    return BillingSnapshot(
      status: BillingStatus.fromDb(json['status']?.toString()),
      writesAllowed: json['writes_allowed'] != false,
      posEnabled: json['pos_enabled'] != false,
      canAddEmployee: json['can_add_employee'] != false,
      activeEmployees: _int(json['active_employees']),
      employeeLimit: _int(json['employee_limit'], 5),
      planCode: (json['plan_code'] ?? 'free').toString(),
      planName: (json['plan_name'] ?? 'Free').toString(),
      graceDays: _int(json['grace_days'], 7),
      currentPeriodEnd: _date(json['current_period_end']),
    );
  }
}

/// Full staff billing console state from `billing_get_state`.
class BillingState {
  const BillingState({
    required this.snapshot,
    required this.plans,
    required this.periods,
    required this.offers,
    this.currentPeriod,
    this.offer,
    this.graceEndsAt,
    this.manualNotes = '',
    this.offerPriceInr,
    this.offerEndsAt,
  });

  final BillingSnapshot snapshot;
  final List<BillingPlan> plans;
  final List<BillingPeriod> periods;
  final List<BillingOffer> offers;
  final BillingPeriod? currentPeriod;
  final BillingOffer? offer;
  final DateTime? graceEndsAt;
  final String manualNotes;
  final double? offerPriceInr;
  final DateTime? offerEndsAt;

  factory BillingState.fromJson(Map<String, dynamic> json) {
    final sub = Map<String, dynamic>.from(
      (json['subscription'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final plan = Map<String, dynamic>.from(
      (json['plan'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final periodRaw = json['current_period'];
    final offerRaw = json['offer'];

    final snapshot = BillingSnapshot(
      status: BillingStatus.fromDb(
        (sub['status'] ?? json['status'])?.toString(),
      ),
      writesAllowed: json['writes_allowed'] != false,
      posEnabled: sub['pos_enabled'] != false,
      canAddEmployee: json['can_add_employee'] != false,
      activeEmployees: _int(json['active_employees']),
      employeeLimit: _int(
        json['employee_limit'] ?? plan['employee_limit'],
        5,
      ),
      planCode: (plan['code'] ?? sub['plan_code'] ?? 'free').toString(),
      planName: (plan['name'] ?? 'Free').toString(),
      graceDays: _int(sub['grace_days'], 7),
      currentPeriodEnd: _date(sub['current_period_end']),
    );

    return BillingState(
      snapshot: snapshot,
      plans: _list(json['plans']).map(BillingPlan.fromJson).toList(),
      periods: _list(json['periods']).map(BillingPeriod.fromJson).toList(),
      offers: _list(json['offers']).map(BillingOffer.fromJson).toList(),
      currentPeriod: periodRaw is Map
          ? BillingPeriod.fromJson(periodRaw.cast<String, dynamic>())
          : null,
      offer: offerRaw is Map
          ? BillingOffer.fromJson(offerRaw.cast<String, dynamic>())
          : null,
      graceEndsAt: _date(json['grace_ends_at']),
      manualNotes: (sub['manual_notes'] ?? '').toString(),
      offerPriceInr:
          sub['offer_price_inr'] == null ? null : _num(sub['offer_price_inr']),
      offerEndsAt: _date(sub['offer_ends_at']),
    );
  }
}

/// Pure helpers mirrored from SQL (for unit tests / offline messaging).
abstract final class BillingRules {
  static bool periodIsSettled(BillingPaymentStatus status) => status.isSettled;

  static BillingStatus deriveStatus({
    required BillingPaymentStatus paymentStatus,
    required DateTime periodEnd,
    required int graceDays,
    DateTime? now,
  }) {
    if (periodIsSettled(paymentStatus)) return BillingStatus.active;
    final clock = now ?? DateTime.now();
    final graceEnd = DateTime(
      periodEnd.year,
      periodEnd.month,
      periodEnd.day,
    ).add(Duration(days: 1 + graceDays));
    if (!clock.isAfter(graceEnd)) return BillingStatus.pastDue;
    return BillingStatus.readOnly;
  }

  static double effectiveAmountDue({
    required double listPriceInr,
    double? offerFixedPrice,
    double? offerPercentOff,
    DateTime? offerEndsAt,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    if (offerEndsAt != null && !offerEndsAt.isAfter(clock)) {
      return listPriceInr < 0 ? 0 : listPriceInr;
    }
    if (offerFixedPrice != null) {
      return offerFixedPrice < 0 ? 0 : offerFixedPrice;
    }
    if (offerPercentOff != null) {
      final v = listPriceInr * (1 - offerPercentOff / 100);
      return v < 0 ? 0 : double.parse(v.toStringAsFixed(2));
    }
    return listPriceInr < 0 ? 0 : listPriceInr;
  }

  static bool canConsumeSeat({
    required int activeEmployees,
    required int employeeLimit,
    required bool writesAllowed,
  }) {
    return writesAllowed && activeEmployees < employeeLimit;
  }

  static String seatLimitMessage({
    required String planCode,
    required int employeeLimit,
  }) {
    if (planCode == 'growth') {
      return 'Employee limit reached ($employeeLimit). Contact us to discuss options.';
    }
    return 'Employee limit reached ($employeeLimit). Upgrade your plan in Settings → Billing.';
  }

  static String readOnlyMessage() =>
      'Subscription is past the grace period. Existing records are view-only until this period is marked paid in Settings → Billing.';
}

double _num(dynamic v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? fallback;
}

int _int(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? fallback;
}

DateTime? _date(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

List<Map<String, dynamic>> _list(dynamic raw) {
  if (raw is! List) return const [];
  return [
    for (final e in raw)
      if (e is Map) Map<String, dynamic>.from(e.cast<String, dynamic>()),
  ];
}
