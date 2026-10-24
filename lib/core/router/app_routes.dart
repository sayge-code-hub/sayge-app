/// Canonical path helpers for go_router destinations.
abstract final class AppRoutes {
  static const login = '/login';
  static const root = '/';
  static const hrms = '/hrms';

  /// Employee single-page home (profile, slip, expenses).
  static const dashboard = '/dashboard';

  /// Dashboard focused on salary slip download.
  static const dashboardSlips = '/dashboard?section=slips';

  /// Employee self-service landing when no `employee_id` is linked yet.
  static const myDetails = '/hrms/me';
  static const employees = '/hrms/employees';
  static const employeesAdd = '/hrms/employees/add';
  static const dms = '/dms';
  static const payroll = '/payroll';
  static const profitability = '/profitability';

  static String profitabilityClient(String cafeId) =>
      '/profitability/$cafeId';

  static String profitabilityProjections(String cafeId) =>
      '/profitability/$cafeId/projections';

  static const proposals = '/proposals';
  static const invoices = '/invoices';
  static const expenses = '/expenses';
  static const settings = '/settings';
  static const clients = '/settings/clients';
  static const clientsAdd = '/settings/clients/add';
  static const companyDetails = '/settings/company';
  static const roles = '/settings/roles';
  static const ledger = '/settings/ledger';
  static const theme = '/settings/theme';
  static const categories = '/settings/categories';
  static const inviteEmployee = '/settings/invite';
  static const manageInvites = '/settings/invites';
  static const setPassword = '/set-password';
  static const pos = '/pos';

  /// Public guest QR menu (no auth). Optional `?t=` table number.
  static const guestMenu = '/m';

  static String guestMenuCafe(String cafeId, {String? tableNo}) {
    final base = '/m/$cafeId';
    final t = tableNo?.trim() ?? '';
    if (t.isEmpty) return base;
    return '$base?t=${Uri.encodeQueryComponent(t)}';
  }

  static String clientDetail(String cafeId) => '/settings/clients/$cafeId';

  static String clientEdit(String cafeId) =>
      '/settings/clients/$cafeId/edit';

  static String employeeDetail(String id) => '/hrms/employees/$id';

  static String employeeEdit(String id) => '/hrms/employees/$id/edit';

  static String employeeCompensation(String id) =>
      '/hrms/employees/$id/compensation';

  static String posCafe(String cafeId) => '/pos/$cafeId';

  static String posMenu(String cafeId) => '/pos/$cafeId/menu';

  static String posMenuAdd(String cafeId) => '/pos/$cafeId/menu/add';

  static String posMenuEdit(String cafeId, String itemId) =>
      '/pos/$cafeId/menu/$itemId/edit';

  static String posCategories(String cafeId) =>
      '/pos/$cafeId/menu/categories';

  static String posTerminal(String cafeId) => '/pos/$cafeId/terminal';

  static String posKitchen(String cafeId) => '/pos/$cafeId/kitchen';

  static String posOrders(String cafeId) => '/pos/$cafeId/orders';

  static String posReports(String cafeId) => '/pos/$cafeId/reports';

  static String posSettings(String cafeId) => '/pos/$cafeId/settings';

  static String posCoupons(String cafeId) => '/pos/$cafeId/settings/coupons';

  static String posTax(String cafeId) => '/pos/$cafeId/settings/tax';

  static String posFloor(String cafeId) => '/pos/$cafeId/settings/floor';

  static String posQr(String cafeId) => '/pos/$cafeId/settings/qr';

  static String posGuestBrand(String cafeId) =>
      '/pos/$cafeId/settings/guest-look';
}
