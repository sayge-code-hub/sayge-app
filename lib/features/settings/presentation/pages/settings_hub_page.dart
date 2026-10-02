import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/app_hub_tile.dart';

class SettingsHubPage extends StatelessWidget {
  const SettingsHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    const tiles = [
      _SettingsTileData(
        title: 'Invite employee',
        subtitle: 'Email invite — they set their password',
        icon: Icons.person_add_alt_1_outlined,
        path: AppRoutes.inviteEmployee,
      ),
      _SettingsTileData(
        title: 'Manage clients',
        subtitle: 'Vendors, contacts, and GSTIN',
        icon: Icons.apartment_outlined,
        path: AppRoutes.clients,
      ),
      _SettingsTileData(
        title: 'GST & company',
        subtitle: 'Legal entity and tax details',
        icon: Icons.receipt_long_outlined,
        path: AppRoutes.companyDetails,
      ),
      _SettingsTileData(
        title: 'Roles',
        subtitle: 'Access and permissions',
        icon: Icons.manage_accounts_outlined,
        path: AppRoutes.roles,
      ),
      _SettingsTileData(
        title: 'Activity ledger',
        subtitle: 'Audit trail of changes',
        icon: Icons.history_outlined,
        path: AppRoutes.ledger,
      ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 32 : 16,
        isDesktop ? 20 : 12,
        isDesktop ? 32 : 16,
        isDesktop ? 32 : 16,
      ),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: tiles.length,
            gridDelegate: AppHubGrid.delegate(
              isDesktop: isDesktop,
              hasSubtitle: true,
            ),
            itemBuilder: (context, index) {
              final tile = tiles[index];
              return AppHubTile(
                title: tile.title,
                subtitle: tile.subtitle,
                icon: tile.icon,
                onTap: () => context.go(tile.path),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SettingsTileData {
  const _SettingsTileData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.path,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String path;
}
