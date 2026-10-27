import 'package:supabase_flutter/supabase_flutter.dart';

import 'billing_models.dart';

class BillingRemoteDataSource {
  BillingRemoteDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<BillingSnapshot> fetchSnapshot() async {
    final raw = await _client.rpc('billing_public_snapshot');
    final map = _asMap(raw);
    return BillingSnapshot.fromJson(map);
  }

  Future<BillingState> getState() async {
    final raw = await _client.rpc('billing_get_state');
    return BillingState.fromJson(_asMap(raw));
  }

  Future<BillingState> setPlan(String planCode) async {
    final raw = await _client.rpc(
      'billing_set_plan',
      params: {'p_plan_code': planCode},
    );
    return BillingState.fromJson(_asMap(raw));
  }

  Future<BillingState> markPeriod({
    required String periodId,
    required BillingPaymentStatus status,
    String? note,
    double? amountPaid,
  }) async {
    final raw = await _client.rpc(
      'billing_mark_period',
      params: {
        'p_period_id': periodId,
        'p_status': status.dbValue,
        'p_note': note,
        'p_amount_paid': amountPaid,
      },
    );
    return BillingState.fromJson(_asMap(raw));
  }

  Future<BillingState> applyOffer({
    required String offerId,
    double? offerPriceInr,
    DateTime? offerEndsAt,
  }) async {
    final raw = await _client.rpc(
      'billing_apply_offer',
      params: {
        'p_offer_id': offerId,
        'p_offer_price_inr': offerPriceInr,
        'p_offer_ends_at': offerEndsAt?.toUtc().toIso8601String(),
      },
    );
    return BillingState.fromJson(_asMap(raw));
  }

  Future<BillingState> clearOffer() async {
    final raw = await _client.rpc('billing_clear_offer');
    return BillingState.fromJson(_asMap(raw));
  }

  Future<BillingState> setGraceDays(int days) async {
    final raw = await _client.rpc(
      'billing_set_grace_days',
      params: {'p_days': days},
    );
    return BillingState.fromJson(_asMap(raw));
  }

  Future<BillingState> setPosEnabled(bool enabled) async {
    final raw = await _client.rpc(
      'billing_set_pos_enabled',
      params: {'p_enabled': enabled},
    );
    return BillingState.fromJson(_asMap(raw));
  }

  Future<BillingState> setNotes(String notes) async {
    final raw = await _client.rpc(
      'billing_set_notes',
      params: {'p_notes': notes},
    );
    return BillingState.fromJson(_asMap(raw));
  }

  Future<BillingState> upsertOffer({
    String? id,
    required String code,
    String name = '',
    String? appliesToPlan,
    double? percentOff,
    double? fixedPriceInr,
    DateTime? startsAt,
    DateTime? endsAt,
    bool isActive = true,
  }) async {
    final raw = await _client.rpc(
      'billing_upsert_offer',
      params: {
        'p_id': id,
        'p_code': code,
        'p_name': name,
        'p_applies_to_plan': appliesToPlan,
        'p_percent_off': percentOff,
        'p_fixed_price_inr': fixedPriceInr,
        'p_starts_at': startsAt?.toUtc().toIso8601String(),
        'p_ends_at': endsAt?.toUtc().toIso8601String(),
        'p_is_active': isActive,
      },
    );
    return BillingState.fromJson(_asMap(raw));
  }

  static Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw StateError('Unexpected billing RPC response');
  }
}

/// Maps Postgres seat-limit exceptions to user-facing copy.
String? mapBillingDbError(Object error, BillingSnapshot snapshot) {
  final text = error.toString();
  if (text.contains('BILLING_SEAT_LIMIT')) {
    return BillingRules.seatLimitMessage(
      planCode: snapshot.planCode,
      employeeLimit: snapshot.employeeLimit,
    );
  }
  if (text.contains('BILLING_FORBIDDEN')) {
    return 'You do not have permission to manage billing.';
  }
  return null;
}
