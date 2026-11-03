import 'package:flutter/material.dart';

import '../router/app_routes.dart';

/// Product packs an owner can opt into after signup.
enum AppModule {
  hrms,
  finances,
  pos,
  assets,
  checklist;

  String get code => name;

  String get title => switch (this) {
        AppModule.hrms => 'HRMS',
        AppModule.finances => 'Finances',
        AppModule.pos => 'POS',
        AppModule.assets => 'Asset Management',
        AppModule.checklist => 'Digital Checklist',
      };

  String get blurb => switch (this) {
        AppModule.hrms => 'People, payroll-ready profiles, and invites',
        AppModule.finances => 'Money in, money out, and client margins',
        AppModule.pos => 'Cafe counter, kitchen, and guest QR menu',
        AppModule.assets => 'Track company assets and assignments',
        AppModule.checklist => 'Recurring ops checklists for your team',
      };

  IconData get icon => switch (this) {
        AppModule.hrms => Icons.groups_rounded,
        AppModule.finances => Icons.account_balance_wallet_rounded,
        AppModule.pos => Icons.storefront_rounded,
        AppModule.assets => Icons.inventory_2_rounded,
        AppModule.checklist => Icons.checklist_rtl_rounded,
      };

  /// Simple feature list shown on hover (web) or expand (mobile).
  List<String> get features => switch (this) {
        AppModule.hrms => const [
            'Employee directory & profiles',
            'Add / invite team members',
            'Roles and access',
            'Documents (DMS)',
          ],
        AppModule.finances => const [
            'Payroll runs & salary slips',
            'Proposals & quotes',
            'Invoices',
            'Expenses & approvals',
            'Client profitability',
          ],
        AppModule.pos => const [
            'Menu & categories',
            'Table terminal',
            'Kitchen display',
            'Orders & reports',
            'Guest QR menu',
          ],
        AppModule.assets => const [
            'Asset register',
            'Assign to people / locations',
            'Status & history',
            'Coming soon in the app shell',
          ],
        AppModule.checklist => const [
            'Daily / weekly checklists',
            'Assign to staff',
            'Completion tracking',
            'Coming soon in the app shell',
          ],
      };

  static const int priceInrPerMonth = 49;

  String get priceLabel => '₹$priceInrPerMonth / month';

  /// Default landing path when this pack is enabled (null = no shell yet).
  String? get homePath => switch (this) {
        AppModule.hrms => AppRoutes.hrms,
        AppModule.finances => AppRoutes.payroll,
        AppModule.pos => AppRoutes.pos,
        AppModule.assets => null,
        AppModule.checklist => null,
      };

  static AppModule? tryParse(String? raw) {
    final code = (raw ?? '').trim().toLowerCase();
    if (code.isEmpty) return null;
    for (final m in AppModule.values) {
      if (m.code == code) return m;
    }
    // Legacy granular codes → packs (older tenants / snapshots).
    return switch (code) {
      'dms' || 'employees' => AppModule.hrms,
      'payroll' ||
      'profitability' ||
      'proposals' ||
      'invoices' ||
      'expenses' =>
        AppModule.finances,
      _ => null,
    };
  }

  static List<AppModule> parseList(Iterable<dynamic>? raw) {
    if (raw == null) return const [];
    final out = <AppModule>[];
    for (final item in raw) {
      final m = tryParse(item?.toString());
      if (m != null && !out.contains(m)) out.add(m);
    }
    return out;
  }

  /// Whether [location] belongs to this pack (staff routes).
  bool coversPath(String location) {
    final path = Uri.tryParse(location)?.path ?? location;
    return switch (this) {
      AppModule.hrms =>
        path == AppRoutes.hrms ||
            path.startsWith('${AppRoutes.hrms}/') ||
            path == AppRoutes.employees ||
            path.startsWith('${AppRoutes.employees}/') ||
            path == AppRoutes.dms ||
            path.startsWith('${AppRoutes.dms}/'),
      AppModule.finances =>
        path == AppRoutes.payroll ||
            path.startsWith('${AppRoutes.payroll}/') ||
            path == AppRoutes.profitability ||
            path.startsWith('${AppRoutes.profitability}/') ||
            path == AppRoutes.proposals ||
            path.startsWith('${AppRoutes.proposals}/') ||
            path == AppRoutes.invoices ||
            path.startsWith('${AppRoutes.invoices}/') ||
            path == AppRoutes.expenses ||
            path.startsWith('${AppRoutes.expenses}/'),
      AppModule.pos =>
        path == AppRoutes.pos || path.startsWith('${AppRoutes.pos}/'),
      AppModule.assets || AppModule.checklist => false,
    };
  }
}
