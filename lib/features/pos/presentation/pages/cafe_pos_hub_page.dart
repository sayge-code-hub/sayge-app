import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_hub_tile.dart';
import '../../../../injection_container.dart';
import '../../domain/usecases/cafe_pos_usecases.dart';

class CafePosHubPage extends StatefulWidget {
  const CafePosHubPage({super.key, required this.cafeId});

  final String cafeId;

  @override
  State<CafePosHubPage> createState() => _CafePosHubPageState();
}

class _CafePosHubPageState extends State<CafePosHubPage> {
  String _title = 'Cafe POS';

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final result = await sl<GetCafes>()();
    result.fold((_) {}, (cafes) {
      for (final c in cafes) {
        if (c.id == widget.cafeId) {
          if (mounted) setState(() => _title = c.name);
          return;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = sl<AuthSession>().user;
    final cafeId = widget.cafeId;
    if (!AppAccess.canAccessCafe(user, cafeId)) {
      return const Center(child: Text('You cannot access this cafe.'));
    }

    final isDesktop = Breakpoints.isDesktop(context);
    final tiles = <AppHubTile>[
      if (AppAccess.canManageCafeMenu(user, cafeId))
        AppHubTile(
          icon: Icons.restaurant_menu_outlined,
          title: 'Menu',
          subtitle: 'Categories and items',
          onTap: () => context.go(AppRoutes.posMenu(cafeId)),
        ),
      if (AppAccess.canRunCafeTerminal(user, cafeId))
        AppHubTile(
          icon: Icons.point_of_sale_outlined,
          title: 'Terminal',
          subtitle: 'Take orders and payments',
          onTap: () => context.go(AppRoutes.posTerminal(cafeId)),
        ),
      if (AppAccess.canRunCafeKitchen(user, cafeId))
        AppHubTile(
          icon: Icons.soup_kitchen_outlined,
          title: 'Kitchen',
          subtitle: 'Prep status board',
          onTap: () => context.go(AppRoutes.posKitchen(cafeId)),
        ),
      if (AppAccess.canRunCafeTerminal(user, cafeId) ||
          AppAccess.canRunCafeKitchen(user, cafeId))
        AppHubTile(
          icon: Icons.receipt_long_outlined,
          title: 'Orders',
          subtitle: 'History and cancellations',
          onTap: () => context.go(AppRoutes.posOrders(cafeId)),
        ),
      if (AppAccess.canViewCafeReports(user, cafeId))
        AppHubTile(
          icon: Icons.bar_chart_outlined,
          title: 'Reports',
          subtitle: 'Daily sales summary',
          onTap: () => context.go(AppRoutes.posReports(cafeId)),
        ),
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 32 : 16,
        16,
        isDesktop ? 32 : 16,
        24,
      ),
      children: [
        Text(
          _title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Cafe point of sale',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textLight,
              ),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final cross = constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 600
                    ? 2
                    : 1;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: cross,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: cross == 1 ? 3.2 : 1.35,
              children: tiles,
            );
          },
        ),
      ],
    );
  }
}
