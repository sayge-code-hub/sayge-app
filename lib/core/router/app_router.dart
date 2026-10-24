import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/set_password_page.dart';
import '../../features/dms/presentation/pages/dms_page.dart';
import '../../features/hrms/domain/entities/employee.dart';
import '../../features/hrms/presentation/bloc/employees/employees_bloc.dart';
import '../../features/hrms/presentation/pages/add_employee_page.dart';
import '../../features/hrms/presentation/pages/compensation_breakup_page.dart';
import '../../features/hrms/presentation/pages/employee_detail_page.dart';
import '../../features/hrms/presentation/pages/employees_page.dart';
import '../../features/hrms/presentation/pages/hrms_overview_page.dart';
import '../../features/hrms/presentation/pages/my_details_page.dart';
import '../../features/modules/presentation/pages/employee_dashboard_page.dart';
import '../../features/modules/presentation/pages/home_shell.dart';
import '../../features/expenses/presentation/pages/expenses_page.dart';
import '../../features/invoices/presentation/pages/invoices_page.dart';
import '../../features/payroll/presentation/pages/payroll_page.dart';
import '../../features/profitability/presentation/pages/profitability_client_page.dart';
import '../../features/profitability/presentation/pages/profitability_page.dart';
import '../../features/profitability/presentation/pages/profitability_projections_page.dart';
import '../../features/pos/presentation/pages/cafe_categories_page.dart';
import '../../features/pos/presentation/pages/cafe_coupons_page.dart';
import '../../features/pos/presentation/pages/cafe_kitchen_page.dart';
import '../../features/pos/presentation/pages/cafe_menu_item_page.dart';
import '../../features/pos/presentation/pages/cafe_menu_page.dart';
import '../../features/pos/presentation/pages/cafe_orders_page.dart';
import '../../features/pos/presentation/pages/cafe_pos_cafes_page.dart';
import '../../features/pos/presentation/pages/cafe_pos_hub_page.dart';
import '../../features/pos/presentation/pages/cafe_guest_menu_page.dart';
import '../../features/pos/presentation/pages/cafe_pos_settings_page.dart';
import '../../features/pos/presentation/pages/cafe_qr_print_page.dart';
import '../../features/pos/presentation/pages/cafe_reports_page.dart';
import '../../features/pos/presentation/pages/cafe_tax_settings_page.dart';
import '../../features/pos/presentation/pages/cafe_terminal_page.dart';
import '../../features/proposals/domain/entities/proposal.dart';
import '../../features/proposals/presentation/pages/proposals_page.dart';
import '../../features/settings/presentation/pages/add_clients_page.dart';
import '../../features/settings/presentation/pages/client_detail_page.dart';
import '../../features/settings/presentation/pages/company_details_page.dart';
import '../../features/settings/presentation/pages/invite_employee_page.dart';
import '../../features/settings/presentation/pages/ledger_page.dart';
import '../../features/settings/presentation/pages/manage_clients_page.dart';
import '../../features/settings/presentation/pages/manage_invites_page.dart';
import '../../features/settings/presentation/pages/roles_page.dart';
import '../../features/settings/presentation/pages/settings_hub_page.dart';
import '../../features/settings/presentation/pages/expense_categories_page.dart';
import '../../features/settings/presentation/pages/theme_page.dart';
import '../auth/app_access.dart';
import '../auth/auth_session.dart';
import '../theme/app_colors.dart';
import 'app_routes.dart';

void _goBack(BuildContext context, String fallback) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

/// Instant route swap — no fade/slide (avoids perceived navigation lag).
Page<void> _page(GoRouterState state, Widget child) {
  return NoTransitionPage<void>(key: state.pageKey, child: child);
}

/// True when hash-based routing (or a mangled invite URL) turned a Supabase
/// auth fragment into a bogus path like `/sb`.
///
/// Only short opaque segments are treated as debris — unknown real paths
/// (e.g. a not-yet-deployed `/m/...`) must not redirect to set-password.
bool _isAuthHashDebris(String location) {
  final path = (Uri.tryParse(location)?.path ?? location).trim();
  if (path.isEmpty || path == AppRoutes.root) return false;
  final segment = path.startsWith('/') ? path.substring(1) : path;
  if (segment.contains('/')) return false;
  // Invite debris: /sb, /error, single opaque tokens — not real app modules.
  if (segment == 'sb' || segment == 'error') return true;
  if (segment.length <= 8 && RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(segment)) {
    const known = {
      'login',
      'dashboard',
      'hrms',
      'dms',
      'payroll',
      'profitability',
      'proposals',
      'invoices',
      'expenses',
      'settings',
      'pos',
      'm',
    };
    return !known.contains(segment.toLowerCase());
  }
  return false;
}

bool _isGuestMenuPath(String location) {
  final path = (Uri.tryParse(location)?.path ?? location).trim();
  return path == AppRoutes.guestMenu ||
      path.startsWith('${AppRoutes.guestMenu}/');
}

GoRouter createAppRouter(AuthSession authSession) {
  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: authSession,
    onException: (_, GoRouterState state, GoRouter router) {
      // Invite links: …/set-password#sb… must never surface as /sb 404.
      if (_isGuestMenuPath(state.uri.path) ||
          _isGuestMenuPath(state.matchedLocation)) {
        // Keep guest URLs on failure instead of bouncing to login/set-password.
        return;
      }
      if (_isAuthHashDebris(state.uri.path) ||
          _isAuthHashDebris(state.matchedLocation)) {
        router.go(AppRoutes.setPassword);
        return;
      }
      router.go(AppRoutes.login);
    },
    redirect: (context, state) {
      final location = state.matchedLocation;
      final uriPath = state.uri.path;

      // Public QR guest menu — no auth shell (check URI path too).
      if (_isGuestMenuPath(location) || _isGuestMenuPath(uriPath)) {
        return null;
      }

      if (_isAuthHashDebris(location) || _isAuthHashDebris(uriPath)) {
        return AppRoutes.setPassword;
      }

      final loggedIn = authSession.isAuthenticated;
      final loggingIn = location == AppRoutes.login;
      final settingPassword = location == AppRoutes.setPassword;
      final atRoot = location == AppRoutes.root;
      final user = authSession.user;

      // Invite / recovery: force password setup before any app module.
      if (authSession.needsPasswordSetup && !settingPassword) {
        return AppRoutes.setPassword;
      }

      // Invitees may already have a Supabase session before AuthSession profile
      // is loaded — never bounce them off set-password.
      if (!loggedIn && !loggingIn && !settingPassword) return AppRoutes.login;
      if (loggedIn && user != null && !authSession.needsPasswordSetup) {
        final home = AppAccess.homeRoute(user);
        if (loggingIn || atRoot) return home;
        if (!AppAccess.canAccessPath(user, location)) return home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => _page(state, const LoginPage()),
      ),
      GoRoute(
        path: AppRoutes.setPassword,
        pageBuilder: (context, state) => _page(state, const SetPasswordPage()),
      ),
      GoRoute(
        path: '/m/:cafeId',
        pageBuilder: (context, state) {
          final cafeId = state.pathParameters['cafeId'] ?? '';
          final table = state.uri.queryParameters['t'] ?? '';
          return _page(
            state,
            CafeGuestMenuPage(cafeId: cafeId, tableNo: table),
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) {
          final user = authSession.user;
          if (user == null) {
            return const SizedBox.shrink();
          }
          final uri = state.uri;
          final location = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
          return HomeShell(user: user, location: location, child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            pageBuilder: (context, state) => _page(
              state,
              EmployeeDashboardPage(
                key: ValueKey(state.uri.toString()),
                showSalarySlips:
                    state.uri.queryParameters['section'] == 'slips',
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.hrms,
            pageBuilder: (context, state) =>
                _page(state, const HrmsOverviewPage()),
          ),
          GoRoute(
            path: AppRoutes.myDetails,
            pageBuilder: (context, state) =>
                _page(state, const MyDetailsPage()),
          ),
          GoRoute(
            path: AppRoutes.employees,
            pageBuilder: (context, state) {
              final user = authSession.user!;
              return _page(
                state,
                EmployeesPage(
                  user: user,
                  embedded: true,
                  onEmployeeSelected: (employee) {
                    context.go(AppRoutes.employeeDetail(employee.employeeId));
                  },
                ),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.employeesAdd,
            pageBuilder: (context, state) => _page(
              state,
              AddEmployeePage(
                embedded: true,
                onCompleted: () {
                  context.read<EmployeesBloc>().add(const EmployeesRequested());
                  context.go(AppRoutes.employees);
                },
                onCancel: () => _goBack(context, AppRoutes.employees),
              ),
            ),
          ),
          GoRoute(
            path: '/hrms/employees/:id',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id']!;
              final staff = AppAccess.isStaff(authSession.user);
              return _page(
                state,
                _EmployeeRoutePage(
                  employeeId: id,
                  builder: (employee) => EmployeeDetailPage(
                    employee: employee,
                    embedded: true,
                    canEdit: staff,
                    showPurchaseOrders: true,
                    canManagePurchaseOrders: staff,
                    showDocuments: true,
                    onBack: staff
                        ? () => _goBack(context, AppRoutes.employees)
                        : null,
                    onEdit: staff
                        ? () => context.go(AppRoutes.employeeEdit(id))
                        : null,
                  ),
                ),
              );
            },
            routes: [
              GoRoute(
                path: 'edit',
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return _page(
                    state,
                    _EmployeeRoutePage(
                      employeeId: id,
                      builder: (employee) => AddEmployeePage(
                        embedded: true,
                        employee: employee,
                        onCompleted: () {
                          context.read<EmployeesBloc>().add(
                            const EmployeesRequested(),
                          );
                          context.go(AppRoutes.employeeDetail(id));
                        },
                        onCancel: () =>
                            _goBack(context, AppRoutes.employeeDetail(id)),
                      ),
                    ),
                  );
                },
              ),
              GoRoute(
                path: 'compensation',
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id']!;
                  final staff = AppAccess.isStaff(authSession.user);
                  return _page(
                    state,
                    _EmployeeRoutePage(
                      employeeId: id,
                      builder: (employee) => CompensationBreakupPage(
                        employee: employee,
                        embedded: true,
                        onBack: () => _goBack(
                          context,
                          staff
                              ? AppRoutes.employeeDetail(id)
                              : AppRoutes.dashboard,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.dms,
            pageBuilder: (context, state) => _page(state, const DmsPage()),
          ),
          GoRoute(
            path: AppRoutes.payroll,
            pageBuilder: (context, state) => _page(state, const PayrollPage()),
          ),
          GoRoute(
            path: AppRoutes.profitability,
            pageBuilder: (context, state) =>
                _page(state, const ProfitabilityPage()),
          ),
          GoRoute(
            path: '/profitability/:clientId',
            pageBuilder: (context, state) => _page(
              state,
              ProfitabilityClientPage(
                clientId: state.pathParameters['clientId'] ?? '',
              ),
            ),
          ),
          GoRoute(
            path: '/profitability/:clientId/projections',
            pageBuilder: (context, state) => _page(
              state,
              ProfitabilityProjectionsPage(
                clientId: state.pathParameters['clientId'] ?? '',
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.proposals,
            pageBuilder: (context, state) =>
                _page(state, const ProposalsPage()),
          ),
          GoRoute(
            path: AppRoutes.invoices,
            pageBuilder: (context, state) {
              final fromProposal = state.extra is Proposal
                  ? state.extra as Proposal
                  : null;
              return _page(
                state,
                InvoicesPage(
                  key: ValueKey(
                    fromProposal == null
                        ? 'invoices'
                        : 'invoices-from-${fromProposal.id}',
                  ),
                  fromProposal: fromProposal,
                ),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.expenses,
            pageBuilder: (context, state) => _page(state, const ExpensesPage()),
          ),
          // Cafe POS — cafe-scoped menu / terminal / kitchen / reports.
          GoRoute(
            path: AppRoutes.pos,
            pageBuilder: (context, state) => _page(
              state,
              CafePosCafesPage(key: ValueKey('pos-hub-${state.uri}')),
            ),
          ),
          GoRoute(
            path: '/pos/:cafeId/menu/add',
            pageBuilder: (context, state) => _page(
              state,
              CafeMenuItemPage(cafeId: state.pathParameters['cafeId']!),
            ),
          ),
          GoRoute(
            path: '/pos/:cafeId/menu/categories',
            pageBuilder: (context, state) => _page(
              state,
              CafeCategoriesPage(cafeId: state.pathParameters['cafeId']!),
            ),
          ),
          GoRoute(
            path: '/pos/:cafeId/menu/:itemId/edit',
            pageBuilder: (context, state) => _page(
              state,
              CafeMenuItemPage(
                cafeId: state.pathParameters['cafeId']!,
                itemId: state.pathParameters['itemId'],
              ),
            ),
          ),
          GoRoute(
            path: '/pos/:cafeId/menu',
            pageBuilder: (context, state) => _page(
              state,
              CafeMenuPage(cafeId: state.pathParameters['cafeId']!),
            ),
          ),
          GoRoute(
            path: '/pos/:cafeId/terminal',
            pageBuilder: (context, state) => _page(
              state,
              CafeTerminalPage(cafeId: state.pathParameters['cafeId']!),
            ),
          ),
          GoRoute(
            path: '/pos/:cafeId/kitchen',
            pageBuilder: (context, state) => _page(
              state,
              CafeKitchenPage(cafeId: state.pathParameters['cafeId']!),
            ),
          ),
          GoRoute(
            path: '/pos/:cafeId/orders',
            pageBuilder: (context, state) => _page(
              state,
              CafeOrdersPage(cafeId: state.pathParameters['cafeId']!),
            ),
          ),
          GoRoute(
            path: '/pos/:cafeId/reports',
            pageBuilder: (context, state) => _page(
              state,
              CafeReportsPage(cafeId: state.pathParameters['cafeId']!),
            ),
          ),
          GoRoute(
            path: '/pos/:cafeId/settings/coupons',
            pageBuilder: (context, state) => _page(
              state,
              CafeCouponsPage(cafeId: state.pathParameters['cafeId']!),
            ),
          ),
          GoRoute(
            path: '/pos/:cafeId/settings/tax',
            pageBuilder: (context, state) => _page(
              state,
              CafeTaxSettingsPage(cafeId: state.pathParameters['cafeId']!),
            ),
          ),
          GoRoute(
            path: '/pos/:cafeId/settings/qr',
            pageBuilder: (context, state) => _page(
              state,
              CafeQrPrintPage(cafeId: state.pathParameters['cafeId']!),
            ),
          ),
          GoRoute(
            path: '/pos/:cafeId/settings',
            pageBuilder: (context, state) => _page(
              state,
              CafePosSettingsPage(cafeId: state.pathParameters['cafeId']!),
            ),
          ),
          GoRoute(
            path: '/pos/:cafeId',
            pageBuilder: (context, state) => _page(
              state,
              CafePosHubPage(cafeId: state.pathParameters['cafeId']!),
            ),
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (context, state) =>
                _page(state, const SettingsHubPage()),
            routes: [
              GoRoute(
                path: 'clients',
                pageBuilder: (context, state) => _page(
                  state,
                  ManageClientsPage(
                    embedded: true,
                    onBack: () => _goBack(context, AppRoutes.settings),
                    onAddClient: () => context.go(AppRoutes.clientsAdd),
                    onOpenClient: (clientId) =>
                        context.go(AppRoutes.clientDetail(clientId)),
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'add',
                    pageBuilder: (context, state) => _page(
                      state,
                      AddClientsPage(
                        embedded: true,
                        onCompleted: () => context.go(AppRoutes.clients),
                        onCancel: () => _goBack(context, AppRoutes.clients),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: ':clientId',
                    pageBuilder: (context, state) {
                      final clientId = state.pathParameters['clientId'] ?? '';
                      return _page(
                        state,
                        ClientDetailPage(
                          clientId: clientId,
                          embedded: true,
                          onBack: () => _goBack(context, AppRoutes.clients),
                          onEdit: (id) => context.go(AppRoutes.clientEdit(id)),
                        ),
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'edit',
                        pageBuilder: (context, state) {
                          final clientId =
                              state.pathParameters['clientId'] ?? '';
                          return _page(
                            state,
                            AddClientsPage(
                              embedded: true,
                              clientId: clientId,
                              onCompleted: () =>
                                  context.go(AppRoutes.clientDetail(clientId)),
                              onCancel: () => _goBack(
                                context,
                                AppRoutes.clientDetail(clientId),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: 'company',
                pageBuilder: (context, state) => _page(
                  state,
                  CompanyDetailsPage(
                    onBack: () => _goBack(context, AppRoutes.settings),
                  ),
                ),
              ),
              GoRoute(
                path: 'roles',
                pageBuilder: (context, state) => _page(
                  state,
                  RolesPage(onBack: () => _goBack(context, AppRoutes.settings)),
                ),
              ),
              GoRoute(
                path: 'ledger',
                pageBuilder: (context, state) => _page(
                  state,
                  LedgerPage(
                    onBack: () => _goBack(context, AppRoutes.settings),
                  ),
                ),
              ),
              GoRoute(
                path: 'theme',
                pageBuilder: (context, state) =>
                    _page(state, const ThemePage()),
              ),
              GoRoute(
                path: 'categories',
                pageBuilder: (context, state) =>
                    _page(state, const ExpenseCategoriesPage()),
              ),
              GoRoute(
                path: 'invite',
                pageBuilder: (context, state) => _page(
                  state,
                  InviteEmployeePage(
                    onBack: () => _goBack(context, AppRoutes.settings),
                  ),
                ),
              ),
              GoRoute(
                path: 'invites',
                pageBuilder: (context, state) => _page(
                  state,
                  ManageInvitesPage(
                    onBack: () => _goBack(context, AppRoutes.settings),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class _EmployeeRoutePage extends StatelessWidget {
  const _EmployeeRoutePage({required this.employeeId, required this.builder});

  final String employeeId;
  final Widget Function(Employee employee) builder;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EmployeesBloc, EmployeesState>(
      builder: (context, state) {
        if (state.status == EmployeesStatus.loading ||
            state.status == EmployeesStatus.initial) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.text),
          );
        }

        Employee? match;
        for (final employee in state.employees) {
          if (employee.employeeId == employeeId) {
            match = employee;
            break;
          }
        }

        if (match == null) {
          return Center(
            child: Text(
              'Employee not found',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }

        return builder(match);
      },
    );
  }
}
