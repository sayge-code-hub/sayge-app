import 'package:flutter/material.dart';

/// Material icons used via [IconData] fields (sidebar, tiles) can be removed by
/// Flutter web's release icon tree-shaker when they never appear as a const
/// [Icon] child. Mount this once (offstage) so those glyphs stay in the font.
class KeptMaterialIcons extends StatelessWidget {
  const KeptMaterialIcons({super.key});

  static const icons = <IconData>[
    Icons.groups_outlined,
    Icons.people_outline,
    Icons.person_add_alt_1_outlined,
    Icons.folder_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.payments_outlined,
    Icons.request_quote_outlined,
    Icons.receipt_long_outlined,
    Icons.account_balance_outlined,
    Icons.storefront_outlined,
    Icons.monetization_on_outlined,
    Icons.point_of_sale_outlined,
    Icons.settings_outlined,
    Icons.dashboard_outlined,
    Icons.logout_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Offstage(
      child: Row(
        children: [
          for (final icon in icons) Icon(icon, size: 1),
        ],
      ),
    );
  }
}
