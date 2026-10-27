import 'package:flutter/material.dart';

import '../../injection_container.dart';
import '../widgets/app_message_dialog.dart';
import 'billing_access.dart';
import 'billing_models.dart';

/// Returns true when people-module writes are allowed.
Future<bool> ensureBillingWritable(BuildContext context) async {
  final billing = sl<BillingAccess>();
  await billing.refresh();
  if (billing.writesAllowed) return true;
  if (!context.mounted) return false;
  await showAppMessageDialog(
    context,
    title: 'Read-only',
    message: BillingRules.readOnlyMessage(),
  );
  return false;
}

/// Returns true when a new employee seat can be consumed.
Future<bool> ensureBillingCanAddEmployee(BuildContext context) async {
  final billing = sl<BillingAccess>();
  await billing.refresh();
  final snap = billing.snapshot;
  if (!snap.writesAllowed) {
    if (!context.mounted) return false;
    await showAppMessageDialog(
      context,
      title: 'Read-only',
      message: BillingRules.readOnlyMessage(),
    );
    return false;
  }
  if (!snap.canAddEmployee) {
    if (!context.mounted) return false;
    await showAppMessageDialog(
      context,
      title: 'Employee limit',
      message: BillingRules.seatLimitMessage(
        planCode: snap.planCode,
        employeeLimit: snap.employeeLimit,
      ),
    );
    return false;
  }
  return true;
}
