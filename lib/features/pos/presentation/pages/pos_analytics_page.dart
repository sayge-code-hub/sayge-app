import 'package:flutter/material.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';

/// Placeholder analytics screen for a brand.
class PosAnalyticsPage extends StatelessWidget {
  const PosAnalyticsPage({super.key, required this.brandId});

  final String brandId;

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16),
        child: Text(
          'Brand analytics will appear here.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textLight,
              ),
        ),
      ),
    );
  }
}
