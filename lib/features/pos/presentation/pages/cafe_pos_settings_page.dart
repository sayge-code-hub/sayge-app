import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../injection_container.dart';
import '../widgets/cafe_pos_chrome.dart';

/// Cafe-scoped POS settings hub (coupons, tax, floor, QR).
class CafePosSettingsPage extends StatelessWidget {
  const CafePosSettingsPage({super.key, required this.cafeId});

  final String cafeId;

  @override
  Widget build(BuildContext context) {
    final user = sl<AuthSession>().user;
    if (!AppAccess.canManageCafeMenu(user, cafeId)) {
      return const CafePosBackdrop(
        child: Center(child: Text('Settings access denied.')),
      );
    }

    return CafePosBackdrop(
      child: ListView(
        padding: CafePosSpace.page(context),
        children: [
          _SettingsTile(
            icon: Icons.local_offer_outlined,
            title: 'Coupon codes',
            onTap: () => context.push(AppRoutes.posCoupons(cafeId)),
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.receipt_long_outlined,
            title: 'Tax configuration',
            onTap: () => context.push(AppRoutes.posTax(cafeId)),
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.table_restaurant_outlined,
            title: 'Floor & tables',
            onTap: () => context.push(AppRoutes.posFloor(cafeId)),
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.qr_code_2_rounded,
            title: 'Guest menu QR',
            onTap: () => context.push(AppRoutes.posQr(cafeId)),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CafePosSpace.radius),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.highlight.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: AppColors.highlight),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textLight.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
