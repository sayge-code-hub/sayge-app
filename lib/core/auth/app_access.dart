import '../../features/auth/domain/entities/user.dart';
import '../router/app_routes.dart';

/// Role-based access for Sayge.
///
/// Staff = owner or admin (full platform access).
/// Cafe roles = cafe_admin / cashier / kitchen (scoped to users.clientId).
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

  static String? cafeClientId(User? user) {
    final id = user?.clientId?.trim() ?? '';
    return id.isEmpty ? null : id;
  }

  static bool canAccessCafeClient(User? user, String clientId) {
    if (user == null) return false;
    if (isStaff(user)) return true;
    final scoped = cafeClientId(user);
    return isCafeRole(user) && scoped != null && scoped == clientId;
  }

  static bool canManageCafeMenu(User? user, String clientId) {
    if (!canAccessCafeClient(user, clientId)) return false;
    return isStaff(user) || isCafeAdmin(user);
  }

  static bool canRunCafeTerminal(User? user, String clientId) {
    if (!canAccessCafeClient(user, clientId)) return false;
    return isStaff(user) || isCafeAdmin(user) || isCashier(user);
  }

  static bool canRunCafeKitchen(User? user, String clientId) {
    if (!canAccessCafeClient(user, clientId)) return false;
    return isStaff(user) || isCafeAdmin(user) || isKitchen(user);
  }

  static bool canViewCafeReports(User? user, String clientId) {
    if (!canAccessCafeClient(user, clientId)) return false;
    return isStaff(user) || isCafeAdmin(user);
  }

  /// Default landing route after login.
  static String homeRoute(User user) {
    if (isStaff(user)) return AppRoutes.hrms;
    if (isKitchen(user)) {
      final clientId = cafeClientId(user);
      if (clientId != null) return AppRoutes.posKitchen(clientId);
      return AppRoutes.pos;
    }
    if (isCashier(user)) {
      final clientId = cafeClientId(user);
      if (clientId != null) return AppRoutes.posTerminal(clientId);
      return AppRoutes.pos;
    }
    if (isCafeAdmin(user)) {
      final clientId = cafeClientId(user);
      if (clientId != null) return AppRoutes.posClient(clientId);
      return AppRoutes.pos;
    }
    return AppRoutes.dashboard;
  }

  /// Whether [location] is allowed for [user].
  static bool canAccessPath(User user, String location) {
    if (isStaff(user)) return true;

    if (isCafeRole(user)) {
      if (location == AppRoutes.pos || location.startsWith('${AppRoutes.pos}/')) {
        final clientId = cafeClientId(user);
        if (clientId == null) return location == AppRoutes.pos;
        if (location == AppRoutes.pos) return true;
        if (!location.startsWith('${AppRoutes.pos}/$clientId')) {
          return false;
        }
        if (location.contains('/menu')) {
          return canManageCafeMenu(user, clientId);
        }
        if (location.contains('/reports')) {
          return canViewCafeReports(user, clientId);
        }
        if (location.contains('/terminal') || location.contains('/orders')) {
          return canRunCafeTerminal(user, clientId) ||
              canRunCafeKitchen(user, clientId);
        }
        if (location.contains('/kitchen')) {
          return canRunCafeKitchen(user, clientId);
        }
        return canAccessCafeClient(user, clientId);
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
