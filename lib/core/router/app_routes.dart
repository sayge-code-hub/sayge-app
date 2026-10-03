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
  static const proposals = '/proposals';
  static const invoices = '/invoices';
  static const expenses = '/expenses';
  static const settings = '/settings';
  static const clients = '/settings/clients';
  static const clientsAdd = '/settings/clients/add';
  static const companyDetails = '/settings/company';
  static const roles = '/settings/roles';
  static const ledger = '/settings/ledger';
  static const inviteEmployee = '/settings/invite';
  static const setPassword = '/set-password';
  static const pos = '/pos';
  static const posHub = '/pos?hub=1';
  static const posBrandAdd = '/pos/brands/add';

  static String employeeDetail(String id) => '/hrms/employees/$id';

  static String employeeEdit(String id) => '/hrms/employees/$id/edit';

  static String employeeCompensation(String id) =>
      '/hrms/employees/$id/compensation';

  static String posBrand(String brandId) => '/pos/$brandId';

  static String posBrandEdit(String brandId) => '/pos/brands/$brandId/edit';

  static String posProducts(String brandId) => '/pos/$brandId';

  static String posProductAdd(String brandId) =>
      '/pos/$brandId/products/add';

  static String posProductEdit(String brandId, String productId) =>
      '/pos/$brandId/products/$productId/edit';

  static String posProductDetail(String brandId, String productId) =>
      '/pos/$brandId/products/$productId';
}
