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
    return AppRoutes.dashboard;
  }

  /// Whether [location] is allowed for [user].
  static bool canAccessPath(User user, String location) {
    if (isStaff(user)) return true;

    if (location == AppRoutes.dashboard) return true;
    if (location == AppRoutes.myDetails) return true;

    // Legacy finance paths — redirect to dashboard via home when denied;
    // still allow compensation deep-link for breakdown.
    if (location == AppRoutes.hrms) return true;

    final id = user.employeeId?.trim();
    if (id != null && id.isNotEmpty) {
      if (location == AppRoutes.employeeCompensation(id)) return true;
    }

    return false;
  }
}
