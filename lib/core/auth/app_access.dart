import '../../features/auth/domain/entities/user.dart';
import '../router/app_routes.dart';

/// Role-based access for Sayge.
///
/// Staff = owner or admin (full access). Everyone else is treated as employee.
abstract final class AppAccess {
  static const staffRoleCodes = {'owner', 'admin'};

  static bool isStaff(User? user) {
    if (user == null) return false;
    return staffRoleCodes.contains(user.roleCode.trim().toLowerCase());
  }

  static bool isEmployeeOnly(User? user) =>
      user != null && !isStaff(user);

  /// Default landing route after login.
  static String homeRoute(User user) {
    if (isStaff(user)) return AppRoutes.hrms;
    final id = user.employeeId?.trim();
    if (id != null && id.isNotEmpty) {
      return AppRoutes.employeeDetail(id);
    }
    return AppRoutes.myDetails;
  }

  /// Whether [location] is allowed for [user].
  static bool canAccessPath(User user, String location) {
    if (isStaff(user)) return true;

    if (location == AppRoutes.myDetails) return true;
    if (location == AppRoutes.payroll) return true;
    if (location == AppRoutes.expenses ||
        location.startsWith('${AppRoutes.expenses}/')) {
      return true;
    }

    // Brief hit on /hrms is redirected to home; allow so redirect can run.
    if (location == AppRoutes.hrms) return true;

    final id = user.employeeId?.trim();
    if (id != null && id.isNotEmpty) {
      if (location == AppRoutes.employeeDetail(id)) return true;
      if (location == AppRoutes.employeeCompensation(id)) return true;
    }

    return false;
  }
}
