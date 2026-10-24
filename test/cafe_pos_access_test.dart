import 'package:flutter_test/flutter_test.dart';
import 'package:sayge_app/core/auth/app_access.dart';
import 'package:sayge_app/core/router/app_routes.dart';
import 'package:sayge_app/features/auth/domain/entities/user.dart';
import 'package:sayge_app/features/pos/domain/entities/cafe_entities.dart';

User _user({
  required String roleCode,
  String? clientId,
  String roleId = 'role_x',
}) {
  return User(
    id: 'u1',
    email: 'a@sayge.in',
    name: 'Test',
    roleId: roleId,
    roleCode: roleCode,
    roleLabel: roleCode,
    clientId: clientId,
  );
}

void main() {
  group('AppAccess cafe POS', () {
    test('staff can access any client cafe', () {
      final user = _user(roleCode: 'owner');
      expect(AppAccess.canAccessCafeClient(user, 'c1'), isTrue);
      expect(AppAccess.canManageCafeMenu(user, 'c1'), isTrue);
      expect(AppAccess.canRunCafeTerminal(user, 'c1'), isTrue);
      expect(AppAccess.canRunCafeKitchen(user, 'c1'), isTrue);
      expect(AppAccess.canViewCafeReports(user, 'c1'), isTrue);
      expect(AppAccess.homeRoute(user), AppRoutes.hrms);
    });

    test('cashier is scoped to client and lands on terminal', () {
      final user = _user(roleCode: 'cashier', clientId: 'cafe-a');
      expect(AppAccess.canAccessCafeClient(user, 'cafe-a'), isTrue);
      expect(AppAccess.canAccessCafeClient(user, 'other'), isFalse);
      expect(AppAccess.canManageCafeMenu(user, 'cafe-a'), isFalse);
      expect(AppAccess.canRunCafeTerminal(user, 'cafe-a'), isTrue);
      expect(AppAccess.canViewCafeReports(user, 'cafe-a'), isFalse);
      expect(AppAccess.homeRoute(user), AppRoutes.posTerminal('cafe-a'));
      expect(
        AppAccess.canAccessPath(user, AppRoutes.posMenu('cafe-a')),
        isFalse,
      );
      expect(
        AppAccess.canAccessPath(user, AppRoutes.posTerminal('cafe-a')),
        isTrue,
      );
    });

    test('kitchen lands on kitchen display', () {
      final user = _user(roleCode: 'kitchen', clientId: 'cafe-a');
      expect(AppAccess.homeRoute(user), AppRoutes.posKitchen('cafe-a'));
      expect(AppAccess.canRunCafeKitchen(user, 'cafe-a'), isTrue);
      expect(AppAccess.canRunCafeTerminal(user, 'cafe-a'), isFalse);
    });

    test('cafe_admin can manage menu and reports', () {
      final user = _user(roleCode: 'cafe_admin', clientId: 'cafe-a');
      expect(AppAccess.homeRoute(user), AppRoutes.posClient('cafe-a'));
      expect(AppAccess.canManageCafeMenu(user, 'cafe-a'), isTrue);
      expect(AppAccess.canViewCafeReports(user, 'cafe-a'), isTrue);
    });
  });

  group('Cafe enums', () {
    test('prep status maps new <-> neu', () {
      expect(CafePrepStatus.neu.dbValue, 'new');
      expect(CafePrepStatusX.fromDb('new'), CafePrepStatus.neu);
      expect(CafePrepStatusX.fromDb('preparing'), CafePrepStatus.preparing);
    });

    test('order type and payment method labels', () {
      expect(CafeOrderType.dineIn.dbValue, 'dine_in');
      expect(CafePaymentMethod.upi.label, 'UPI');
    });
  });
}
