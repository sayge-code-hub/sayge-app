import 'package:flutter/material.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';

/// Placeholder checkout / billing screen for a brand.
class PosTerminalPage extends StatelessWidget {
  const PosTerminalPage({super.key, required this.brandId});

  final String brandId;

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16),
        child: Text(
          'POS checkout for this brand will appear here.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textLight,
              ),
        ),
      ),
    );
  }
}
