import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../injection_container.dart';
import '../../domain/usecases/cafe_pos_usecases.dart';
import '../widgets/cafe_pos_chrome.dart';

class CafePosHubPage extends StatefulWidget {
  const CafePosHubPage({super.key, required this.cafeId});

  final String cafeId;

  @override
  State<CafePosHubPage> createState() => _CafePosHubPageState();
}

class _CafePosHubPageState extends State<CafePosHubPage> {
  String _title = 'Cafe';

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
      return const CafePosBackdrop(
        child: Center(child: Text('You cannot access this cafe.')),
      );
    }

    final tiles = <CafePosNavTile>[
      if (AppAccess.canManageCafeMenu(user, cafeId))
        CafePosNavTile(
          icon: Icons.restaurant_menu_outlined,
          title: 'Menu',
          subtitle: 'Categories & prices',
          onTap: () => context.go(AppRoutes.posMenu(cafeId)),
        ),
      if (AppAccess.canRunCafeTerminal(user, cafeId))
        CafePosNavTile(
          icon: Icons.point_of_sale_outlined,
          title: 'Terminal',
          subtitle: 'Orders & payments',
          onTap: () => context.go(AppRoutes.posTerminal(cafeId)),
        ),
      if (AppAccess.canRunCafeKitchen(user, cafeId))
        CafePosNavTile(
          icon: Icons.soup_kitchen_outlined,
          title: 'Kitchen',
          subtitle: 'Prep status board',
          onTap: () => context.go(AppRoutes.posKitchen(cafeId)),
        ),
      if (AppAccess.canRunCafeTerminal(user, cafeId) ||
          AppAccess.canRunCafeKitchen(user, cafeId))
        CafePosNavTile(
          icon: Icons.receipt_long_outlined,
          title: 'Orders',
          subtitle: 'History & cancel',
          onTap: () => context.go(AppRoutes.posOrders(cafeId)),
        ),
      if (AppAccess.canViewCafeReports(user, cafeId))
        CafePosNavTile(
          icon: Icons.bar_chart_outlined,
          title: 'Reports',
          subtitle: 'Daily sales',
          onTap: () => context.go(AppRoutes.posReports(cafeId)),
        ),
      if (AppAccess.canManageCafeMenu(user, cafeId))
        CafePosNavTile(
          icon: Icons.settings_outlined,
          title: 'Settings',
          subtitle: 'Coupons, tax & QR menu',
          onTap: () => context.go(AppRoutes.posSettings(cafeId)),
        ),
    ];

    return CafePosBackdrop(
      child: ListView(
        padding: CafePosSpace.page(context),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CafePosMonogram(label: _title, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: CafePosPageHeader(
                  title: _title,
                  subtitle: 'Choose a station to continue',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final cross = w >= 1100
                  ? 5
                  : w >= 820
                      ? 4
                      : w >= 560
                          ? 3
                          : 2;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: cross,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: cross >= 4 ? 1.45 : (cross >= 3 ? 1.35 : 1.25),
                children: tiles,
              );
            },
          ),
          if (tiles.isEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'No POS actions available for your role.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textLight,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
