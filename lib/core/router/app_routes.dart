/// Canonical path helpers for go_router destinations.
abstract final class AppRoutes {
  static const login = '/login';
  static const root = '/';
  static const hrms = '/hrms';
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

  static String employeeDetail(String id) => '/hrms/employees/$id';

  static String employeeEdit(String id) => '/hrms/employees/$id/edit';

  static String employeeCompensation(String id) =>
      '/hrms/employees/$id/compensation';
}
