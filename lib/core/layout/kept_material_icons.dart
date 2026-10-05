import 'package:flutter/material.dart';

/// Material icons used via [IconData] fields (sidebar, tiles) can be removed by
/// Flutter web's release icon tree-shaker when they never appear as a const
/// [Icon] child. Mount this once (offstage) so those glyphs stay in the font.
class KeptMaterialIcons extends StatelessWidget {
  const KeptMaterialIcons({super.key});

  @override
  Widget build(BuildContext context) {
    return const Offstage(
      child: Row(
        children: [
          Icon(Icons.groups_outlined, size: 1),
          Icon(Icons.people_outline, size: 1),
          Icon(Icons.person_add_alt_1_outlined, size: 1),
          Icon(Icons.folder_outlined, size: 1),
          Icon(Icons.account_balance_wallet_outlined, size: 1),
          Icon(Icons.payments_outlined, size: 1),
          Icon(Icons.request_quote_outlined, size: 1),
          Icon(Icons.receipt_long_outlined, size: 1),
          Icon(Icons.account_balance_outlined, size: 1),
          Icon(Icons.storefront_outlined, size: 1),
          Icon(Icons.monetization_on_outlined, size: 1),
          Icon(Icons.point_of_sale_outlined, size: 1),
          Icon(Icons.settings_outlined, size: 1),
          Icon(Icons.dashboard_outlined, size: 1),
          Icon(Icons.logout_rounded, size: 1),
        ],
      ),
    );
  }
}
