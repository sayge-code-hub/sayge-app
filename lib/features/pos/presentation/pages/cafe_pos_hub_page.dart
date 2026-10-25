import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../injection_container.dart';
import '../widgets/cafe_pos_chrome.dart';

class CafePosHubPage extends StatelessWidget {
  const CafePosHubPage({super.key, required this.cafeId});

  final String cafeId;

  @override
  Widget build(BuildContext context) {
    final user = sl<AuthSession>().user;
    if (!AppAccess.canAccessCafe(user, cafeId)) {
      return const CafePosBackdrop(
        child: Center(child: Text('You cannot access this cafe.')),
      );
    }

    final tiles = <CafePosNavTile>[
      if (AppAccess.canManageCafeMenu(user, cafeId))
        CafePosNavTile(
          icon: Icons.restaurant_menu_outlined,
          title: 'Menu',
          onTap: () => context.go(AppRoutes.posMenu(cafeId)),
        ),
      if (AppAccess.canManageCafeMenu(user, cafeId))
        CafePosNavTile(
          icon: Icons.category_outlined,
          title: 'Categories',
          onTap: () => context.go(AppRoutes.posCategories(cafeId)),
        ),
      if (AppAccess.canRunCafeTerminal(user, cafeId))
        CafePosNavTile(
          icon: Icons.point_of_sale_outlined,
          title: 'Terminal',
          onTap: () => context.go(AppRoutes.posTerminal(cafeId)),
        ),
      if (AppAccess.canRunCafeKitchen(user, cafeId))
        CafePosNavTile(
          icon: Icons.soup_kitchen_outlined,
          title: 'Kitchen',
          onTap: () => context.go(AppRoutes.posKitchen(cafeId)),
        ),
      if (AppAccess.canRunCafeTerminal(user, cafeId) ||
          AppAccess.canRunCafeKitchen(user, cafeId))
        CafePosNavTile(
          icon: Icons.receipt_long_outlined,
          title: 'Orders',
          onTap: () => context.go(AppRoutes.posOrders(cafeId)),
        ),
      if (AppAccess.canViewCafeReports(user, cafeId))
        CafePosNavTile(
          icon: Icons.bar_chart_outlined,
          title: 'Reports',
          onTap: () => context.go(AppRoutes.posReports(cafeId)),
        ),
      if (AppAccess.canManageCafeMenu(user, cafeId))
        CafePosNavTile(
          icon: Icons.settings_outlined,
          title: 'Settings',
          onTap: () => context.go(AppRoutes.posSettings(cafeId)),
        ),
    ];

    return CafePosBackdrop(
      child: ListView(
        padding: CafePosSpace.page(context),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final cross = w >= 1100
                  ? 4
                  : w >= 820
                      ? 3
                      : w >= 560
                          ? 3
                          : 2;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: cross,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.05,
                children: tiles,
              );
            },
          ),
        ],
      ),
    );
  }
}
