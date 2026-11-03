import '../../features/auth/domain/entities/user.dart';
import '../billing/billing_access.dart';
import '../modules/app_modules.dart';
import '../router/app_routes.dart';
import '../../injection_container.dart';

/// Role-based access for Sayge.
///
/// Staff = owner or admin (full platform access).
/// Cafe roles = cafe_admin / cashier / kitchen (scoped to users.cafeId).
abstract final class AppAccess {
  static const staffRoleCodes = {'owner', 'admin'};
  static const cafeRoleCodes = {'cafe_admin', 'cashier', 'kitchen'};

  static String _code(User? user) =>
      (user?.roleCode ?? '').trim().toLowerCase();

  static bool isStaff(User? user) {
    if (user == null) return false;
    return staffRoleCodes.contains(_code(user));
  }

  static bool isCafeRole(User? user) {
    if (user == null) return false;
    return cafeRoleCodes.contains(_code(user));
  }

  static bool isCafeAdmin(User? user) => _code(user) == 'cafe_admin';

  static bool isCashier(User? user) => _code(user) == 'cashier';

  static bool isKitchen(User? user) => _code(user) == 'kitchen';

  static bool isEmployeeOnly(User? user) =>
      user != null && !isStaff(user) && !isCafeRole(user);

  static String? cafeIdOf(User? user) {
    final id = user?.cafeId?.trim() ?? '';
    return id.isEmpty ? null : id;
  }

  static bool canAccessCafe(User? user, String cafeId) {
    if (user == null) return false;
    if (isStaff(user)) return true;
    final scoped = cafeIdOf(user);
    return isCafeRole(user) && scoped != null && scoped == cafeId;
  }

  static bool canManageCafeMenu(User? user, String cafeId) {
    if (!canAccessCafe(user, cafeId)) return false;
    return isStaff(user) || isCafeAdmin(user);
  }

  static bool canRunCafeTerminal(User? user, String cafeId) {
    if (!canAccessCafe(user, cafeId)) return false;
    return isStaff(user) || isCafeAdmin(user) || isCashier(user);
  }

  static bool canRunCafeKitchen(User? user, String cafeId) {
    if (!canAccessCafe(user, cafeId)) return false;
    return isStaff(user) || isCafeAdmin(user) || isKitchen(user);
  }

  static bool canViewCafeReports(User? user, String cafeId) {
    if (!canAccessCafe(user, cafeId)) return false;
    return isStaff(user) || isCafeAdmin(user);
  }

  /// Default landing route after login.
  static String homeRoute(User user) {
    if (isStaff(user)) {
      final billing = sl<BillingAccess>();
      if (!billing.loaded || !billing.modulesSelected) {
        return AppRoutes.onboardingModules;
      }
      return billing.firstModuleHome;
    }
    if (isKitchen(user)) {
      final cafeId = cafeIdOf(user);
      if (cafeId != null) return AppRoutes.posKitchen(cafeId);
      return AppRoutes.pos;
    }
    if (isCashier(user)) {
      final cafeId = cafeIdOf(user);
      if (cafeId != null) return AppRoutes.posTerminal(cafeId);
      return AppRoutes.pos;
    }
    if (isCafeAdmin(user)) {
      final cafeId = cafeIdOf(user);
      if (cafeId != null) return AppRoutes.posCafe(cafeId);
      return AppRoutes.pos;
    }
    return AppRoutes.dashboard;
  }

  /// Whether staff may open [location] given company module opt-in.
  static bool staffModuleAllows(String location) {
    final path = Uri.tryParse(location)?.path ?? location;
    if (path == AppRoutes.settings ||
        path.startsWith('${AppRoutes.settings}/') ||
        path == AppRoutes.onboardingModules ||
        path.startsWith('${AppRoutes.onboardingModules}/') ||
        path == AppRoutes.whatsNew ||
        path.startsWith('${AppRoutes.whatsNew}/')) {
      return true;
    }
    final billing = sl<BillingAccess>();
    if (!billing.modulesSelected) {
      return path == AppRoutes.onboardingModules;
    }
    for (final m in AppModule.values) {
      if (billing.hasModule(m) && m.coversPath(path)) return true;
    }
    return false;
  }

  /// Whether [location] is allowed for [user].
  static bool canAccessPath(User user, String location) {
    if (location == AppRoutes.whatsNew ||
        location.startsWith('${AppRoutes.whatsNew}/')) {
      return true;
    }
    if (isStaff(user)) return staffModuleAllows(location);

    if (isCafeRole(user)) {
      if (location == AppRoutes.pos || location.startsWith('${AppRoutes.pos}/')) {
        final cafeId = cafeIdOf(user);
        if (cafeId == null) return location == AppRoutes.pos;
        if (location == AppRoutes.pos) return true;
        if (!location.startsWith('${AppRoutes.pos}/$cafeId')) {
          return false;
        }
        if (location.contains('/menu') || location.contains('/settings')) {
          return canManageCafeMenu(user, cafeId);
        }
        if (location.contains('/reports')) {
          return canViewCafeReports(user, cafeId);
        }
        if (location.contains('/terminal') || location.contains('/orders')) {
          return canRunCafeTerminal(user, cafeId) ||
              canRunCafeKitchen(user, cafeId);
        }
        if (location.contains('/kitchen')) {
          return canRunCafeKitchen(user, cafeId);
        }
        return canAccessCafe(user, cafeId);
      }
      return false;
    }

    if (location == AppRoutes.dashboard) return true;
    if (location == AppRoutes.myDetails) return true;
    if (location == AppRoutes.hrms) return true;

    final id = user.employeeId?.trim();
    if (id != null && id.isNotEmpty) {
      if (location == AppRoutes.employeeCompensation(id)) return true;
      if (location == AppRoutes.expenses ||
          location.startsWith('${AppRoutes.expenses}/')) {
        return true;
      }
    }

    return false;
  }
}
